#!/bin/bash

# Manual Kubernetes Installation Script
# Installs K8s cluster using direct commands without package conflicts

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Configuration
CLUSTER_ENDPOINT="10.1.1.10:6443"
POD_CIDR="10.244.0.0/16"
SERVICE_CIDR="10.96.0.0/12"

MASTER_NODES=("10.1.1.11" "10.1.1.12" "10.1.1.13")
WORKER_NODES=("10.1.1.21" "10.1.1.22" "10.1.1.23" "10.1.1.25" "10.1.1.26" "10.1.1.27")
LB_NODE="10.1.1.10"
STORAGE_NODE="10.1.1.30"

# Install prerequisites on a node
install_prerequisites() {
    local node=$1
    log "Installing prerequisites on $node..."
    
    ssh -o StrictHostKeyChecking=no ubuntu@$node '
        # Disable swap
        sudo swapoff -a
        sudo sed -i "/ swap / s/^/#/" /etc/fstab
        
        # Load kernel modules
        sudo modprobe overlay
        sudo modprobe br_netfilter
        
        # Configure kernel modules at boot
        cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
        
        # Configure sysctl
        cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
        sudo sysctl --system
        
        # Install containerd
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg lsb-release
        
        # Add Docker GPG key and repo for containerd
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        sudo apt-get update
        sudo apt-get install -y containerd.io
        
        # Configure containerd
        sudo mkdir -p /etc/containerd
        containerd config default | sudo tee /etc/containerd/config.toml
        sudo sed -i "s/SystemdCgroup = false/SystemdCgroup = true/" /etc/containerd/config.toml
        sudo systemctl restart containerd
        sudo systemctl enable containerd
        
        # Install Kubernetes
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
        
        sudo apt-get update
        sudo apt-get install -y kubelet kubeadm kubectl
        sudo apt-mark hold kubelet kubeadm kubectl
        sudo systemctl enable kubelet
    '
}

# Setup HAProxy load balancer
setup_load_balancer() {
    log "Setting up HAProxy load balancer on $LB_NODE..."
    
    ssh -o StrictHostKeyChecking=no ubuntu@$LB_NODE '
        sudo apt-get update
        sudo apt-get install -y haproxy
        
        # Configure HAProxy
        cat <<EOF | sudo tee /etc/haproxy/haproxy.cfg
global
    daemon
    log stdout local0
    
defaults
    mode tcp
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
    log global
    
frontend kubernetes-frontend
    bind *:6443
    default_backend kubernetes-backend
    
backend kubernetes-backend
    balance roundrobin
    server master-1 10.1.1.11:6443 check
    server master-2 10.1.1.12:6443 check
    server master-3 10.1.1.13:6443 check
    
listen stats
    bind *:8080
    stats enable
    stats uri /stats
EOF
        
        sudo systemctl restart haproxy
        sudo systemctl enable haproxy
    '
}

# Initialize first master node
init_first_master() {
    log "Initializing first master node (${MASTER_NODES[0]})..."
    
    ssh -o StrictHostKeyChecking=no ubuntu@${MASTER_NODES[0]} "
        sudo kubeadm init \
            --control-plane-endpoint=\"$CLUSTER_ENDPOINT\" \
            --upload-certs \
            --apiserver-advertise-address=${MASTER_NODES[0]} \
            --pod-network-cidr=$POD_CIDR \
            --service-cidr=$SERVICE_CIDR
        
        # Setup kubectl for ubuntu user
        mkdir -p \$HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config
        sudo chown ubuntu:ubuntu \$HOME/.kube/config
        
        # Install Calico CNI
        kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/tigera-operator.yaml
        
        # Create custom Calico configuration
        cat <<EOF | kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: $POD_CIDR
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
EOF
        
        # Generate join commands
        echo '# Control Plane Join Command:' > /tmp/join-commands.txt
        kubeadm token create --print-join-command --certificate-key \$(kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -1) >> /tmp/join-commands.txt
        echo '# Worker Join Command:' >> /tmp/join-commands.txt
        kubeadm token create --print-join-command >> /tmp/join-commands.txt
    "
    
    # Copy join commands
    scp -o StrictHostKeyChecking=no ubuntu@${MASTER_NODES[0]}:/tmp/join-commands.txt /tmp/
    
    log "First master initialized successfully"
}

# Join additional master nodes
join_masters() {
    log "Joining additional master nodes..."
    
    local cp_join_cmd=$(grep -A1 "Control Plane Join Command:" /tmp/join-commands.txt | tail -1)
    
    for master in "${MASTER_NODES[@]:1}"; do
        log "Joining master node $master..."
        ssh -o StrictHostKeyChecking=no ubuntu@$master "
            $cp_join_cmd --control-plane
            
            # Setup kubectl
            mkdir -p \$HOME/.kube
            sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config
            sudo chown ubuntu:ubuntu \$HOME/.kube/config
        "
    done
}

# Join worker nodes
join_workers() {
    log "Joining worker nodes..."
    
    local worker_join_cmd=$(grep -A1 "Worker Join Command:" /tmp/join-commands.txt | tail -1)
    
    for worker in "${WORKER_NODES[@]}"; do
        log "Joining worker node $worker..."
        ssh -o StrictHostKeyChecking=no ubuntu@$worker "$worker_join_cmd" || warning "Failed to join $worker"
    done
}

# Setup NFS storage
setup_nfs_storage() {
    log "Setting up NFS storage on $STORAGE_NODE..."
    
    ssh -o StrictHostKeyChecking=no ubuntu@$STORAGE_NODE '
        sudo apt-get update
        sudo apt-get install -y nfs-kernel-server nfs-common
        
        # Create NFS directories
        sudo mkdir -p /srv/nfs/{k8s-pvs,backups,media,configs}
        sudo chown -R nobody:nogroup /srv/nfs/
        sudo chmod -R 777 /srv/nfs/
        
        # Configure NFS exports
        cat <<EOF | sudo tee /etc/exports
/srv/nfs/k8s-pvs  10.1.1.0/24(rw,sync,no_subtree_check,no_root_squash)
/srv/nfs/backups  10.1.1.0/24(rw,sync,no_subtree_check,no_root_squash)
/srv/nfs/media    10.1.1.0/24(rw,sync,no_subtree_check,no_root_squash)
/srv/nfs/configs  10.1.1.0/24(rw,sync,no_subtree_check,no_root_squash)
EOF
        
        sudo exportfs -ra
        sudo systemctl restart nfs-kernel-server
        sudo systemctl enable nfs-kernel-server
    '
}

# Configure cluster
configure_cluster() {
    log "Configuring cluster..."
    
    # Copy kubeconfig to jump host
    scp -o StrictHostKeyChecking=no ubuntu@${MASTER_NODES[0]}:~/.kube/config ~/.kube/config
    chmod 600 ~/.kube/config
    
    # Label nodes
    ssh -o StrictHostKeyChecking=no ubuntu@${MASTER_NODES[0]} '
        # Wait for nodes to be ready
        sleep 30
        
        # Label worker nodes
        for node in k8s-worker-01 k8s-worker-02 k8s-worker-03 k8s-worker-05 k8s-worker-06 k8s-worker-07; do
            kubectl label node $node node-role.kubernetes.io/worker=worker --overwrite || true
        done
        
        # Install MetalLB
        kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
        
        # Wait for MetalLB
        sleep 30
        
        # Configure MetalLB IP pool
        cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: homelab-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.1.1.100-10.1.1.150
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: homelab-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - homelab-pool
EOF
    '
    
    log "✅ Kubernetes cluster setup completed!"
}

# Main execution
main() {
    log "🚀 Starting manual Kubernetes installation..."
    
    # Install prerequisites on all nodes
    for node in "${MASTER_NODES[@]}" "${WORKER_NODES[@]}" "$LB_NODE" "$STORAGE_NODE"; do
        install_prerequisites $node &
    done
    wait
    
    # Setup infrastructure
    setup_load_balancer
    setup_nfs_storage
    
    # Initialize cluster
    init_first_master
    join_masters
    join_workers
    configure_cluster
    
    log "🎉 Kubernetes cluster deployment completed!"
    
    # Show cluster status
    kubectl get nodes -o wide
    kubectl get pods -A
}

main "$@"