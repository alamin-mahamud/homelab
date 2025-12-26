#!/bin/bash

# K8s Cluster VM Creation Script for Proxmox
# Creates VMs for a complete K8s cluster with HA control plane

set -e

PROXMOX_HOST="10.1.0.0"
TEMPLATE_ID=999
STORAGE="local-lvm"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# VM Configuration
declare -A VM_CONFIG=(
    # Control Plane Nodes (3)
    ["1001"]="k8s-master-01,4,8192,10.2.0.11"
    ["1002"]="k8s-master-02,4,8192,10.2.0.12"
    ["1003"]="k8s-master-03,4,8192,10.2.0.13"
    
    # Worker Nodes (7)
    ["1011"]="k8s-worker-01,4,12288,10.2.0.21"
    ["1012"]="k8s-worker-02,4,12288,10.2.0.22"
    ["1013"]="k8s-worker-03,4,12288,10.2.0.23"
    ["1014"]="k8s-worker-04,4,12288,10.2.0.24"
    ["1015"]="k8s-worker-05,4,12288,10.2.0.25"
    ["1016"]="k8s-worker-06,4,12288,10.2.0.26"
    ["1017"]="k8s-worker-07,4,12288,10.2.0.27"
    
    # Load Balancer
    ["1020"]="k8s-lb-haproxy,2,4096,10.2.0.10"
    
    # Storage Node
    ["1021"]="k8s-storage,4,8192,10.2.0.30"
)

# Function to create VM
create_vm() {
    local vmid=$1
    local config=$2
    IFS=',' read -r name cores memory ip <<< "$config"
    
    log "Creating VM $vmid: $name (${cores} cores, ${memory}MB RAM, IP: $ip)"
    
    # Clone from template
    ssh root@$PROXMOX_HOST "qm clone $TEMPLATE_ID $vmid --name $name --full" || {
        warning "VM $vmid might already exist, checking..."
        ssh root@$PROXMOX_HOST "qm status $vmid" 2>/dev/null && {
            warning "VM $vmid exists, skipping..."
            return
        }
        error "Failed to create VM $vmid"
    }
    
    # Configure VM resources
    ssh root@$PROXMOX_HOST "
        qm set $vmid --cores $cores --memory $memory --balloon 0
        qm set $vmid --net0 virtio,bridge=vmbr0
        qm set $vmid --ipconfig0 ip=$ip/24,gw=10.2.0.1
        qm set $vmid --nameserver 8.8.8.8
        qm set $vmid --searchdomain homelab.local
        qm set $vmid --agent enabled=1
        qm set $vmid --onboot 1
        qm resize $vmid scsi0 +30G
    "
    
    # Add tags based on role
    if [[ $name == *"master"* ]]; then
        ssh root@$PROXMOX_HOST "qm set $vmid --tags k8s-control-plane"
    elif [[ $name == *"worker"* ]]; then
        ssh root@$PROXMOX_HOST "qm set $vmid --tags k8s-worker"
    elif [[ $name == *"lb"* ]]; then
        ssh root@$PROXMOX_HOST "qm set $vmid --tags load-balancer"
    elif [[ $name == *"storage"* ]]; then
        ssh root@$PROXMOX_HOST "qm set $vmid --tags storage"
    fi
    
    log "VM $vmid ($name) created successfully"
}

# Function to start VM
start_vm() {
    local vmid=$1
    log "Starting VM $vmid..."
    ssh root@$PROXMOX_HOST "qm start $vmid" || warning "VM $vmid might be already running"
}

# Main execution
main() {
    log "Starting K8s cluster VM deployment on Proxmox"
    log "Using template ID: $TEMPLATE_ID"
    log "Target Proxmox host: $PROXMOX_HOST"
    
    # Create all VMs
    for vmid in "${!VM_CONFIG[@]}"; do
        create_vm "$vmid" "${VM_CONFIG[$vmid]}"
    done
    
    log "All VMs created. Starting VMs..."
    
    # Start all VMs
    for vmid in "${!VM_CONFIG[@]}"; do
        start_vm "$vmid"
    done
    
    log "Waiting for VMs to boot and become accessible..."
    sleep 30
    
    # Generate inventory file for Ansible
    log "Generating Ansible inventory..."
    cat > /home/ubuntu/src/homelab/deployment/inventory.ini <<EOF
[k8s_masters]
10.2.0.11 hostname=k8s-master-01
10.2.0.12 hostname=k8s-master-02
10.2.0.13 hostname=k8s-master-03

[k8s_workers]
10.2.0.21 hostname=k8s-worker-01
10.2.0.22 hostname=k8s-worker-02
10.2.0.23 hostname=k8s-worker-03
10.2.0.24 hostname=k8s-worker-04
10.2.0.25 hostname=k8s-worker-05
10.2.0.26 hostname=k8s-worker-06
10.2.0.27 hostname=k8s-worker-07

[k8s_lb]
10.2.0.10 hostname=k8s-lb-haproxy

[k8s_storage]
10.2.0.30 hostname=k8s-storage

[k8s_cluster:children]
k8s_masters
k8s_workers

[all:vars]
ansible_user=ubuntu
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
ansible_ssh_pass=ubuntu
ansible_become_pass=ubuntu
EOF
    
    log "✅ K8s cluster VMs deployment completed!"
    log "📋 Inventory file created at: /home/ubuntu/src/homelab/deployment/inventory.ini"
    log "Total VMs created: ${#VM_CONFIG[@]}"
    echo ""
    echo "Next steps:"
    echo "1. Wait for VMs to fully boot (2-3 minutes)"
    echo "2. Run ansible playbook to configure K8s cluster"
    echo "3. Deploy homelab services"
}

# Run main function
main "$@"