#!/bin/bash

# Cleanup script to remove conflicting repositories and packages
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# All nodes
MASTER_NODES=("10.1.1.11" "10.1.1.12" "10.1.1.13")
WORKER_NODES=("10.1.1.21" "10.1.1.22" "10.1.1.23" "10.1.1.25" "10.1.1.26" "10.1.1.27")
LB_NODE="10.1.1.10"
STORAGE_NODE="10.1.1.30"

# Clean up a node
cleanup_node() {
    local node=$1
    log "Cleaning up node $node..."
    
    ssh -o StrictHostKeyChecking=no ubuntu@$node '
        # Stop and remove Kubernetes services
        sudo systemctl stop kubelet || true
        sudo systemctl disable kubelet || true
        
        # Remove Kubernetes packages
        sudo apt-mark unhold kubelet kubeadm kubectl || true
        sudo apt-get remove -y kubelet kubeadm kubectl || true
        
        # Stop and remove containerd
        sudo systemctl stop containerd || true
        sudo systemctl disable containerd || true
        sudo apt-get remove -y containerd.io || true
        
        # Remove Docker repository entries
        sudo rm -f /etc/apt/sources.list.d/docker.list || true
        sudo rm -f /etc/apt/keyrings/docker.gpg || true
        
        # Remove Kubernetes repository entries
        sudo rm -f /etc/apt/sources.list.d/kubernetes.list || true
        sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg || true
        
        # Clean apt cache
        sudo apt-get clean
        sudo apt-get autoclean
        sudo apt-get autoremove -y
        
        # Remove Kubernetes configuration
        sudo rm -rf /etc/kubernetes/ || true
        sudo rm -rf /var/lib/kubelet/ || true
        sudo rm -rf /var/lib/etcd/ || true
        sudo rm -rf ~/.kube/ || true
        
        # Remove containerd configuration
        sudo rm -rf /etc/containerd/ || true
        sudo rm -rf /var/lib/containerd/ || true
        
        # Reset iptables
        sudo iptables -F || true
        sudo iptables -X || true
        sudo iptables -t nat -F || true
        sudo iptables -t nat -X || true
        sudo iptables -t mangle -F || true
        sudo iptables -t mangle -X || true
        
        # Reset network interfaces
        sudo ip link delete cni0 || true
        sudo ip link delete flannel.1 || true
        
        log "Node $node cleaned successfully"
    '
}

# Main cleanup
main() {
    log "🧹 Starting cleanup of all Kubernetes nodes..."
    
    # Clean up all nodes in parallel
    for node in "${MASTER_NODES[@]}" "${WORKER_NODES[@]}" "$LB_NODE" "$STORAGE_NODE"; do
        cleanup_node $node &
    done
    wait
    
    log "✅ All nodes cleaned successfully!"
}

main "$@"