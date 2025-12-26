#!/bin/bash

# Deep cleanup script to completely remove all Docker and K8s repositories
set -e

GREEN='\033[0;32m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }

MASTER_NODES=("10.1.1.11" "10.1.1.12" "10.1.1.13")
WORKER_NODES=("10.1.1.21" "10.1.1.22" "10.1.1.23" "10.1.1.25" "10.1.1.26" "10.1.1.27")
LB_NODE="10.1.1.10"
STORAGE_NODE="10.1.1.30"

deep_cleanup_node() {
    local node=$1
    log "Deep cleaning node $node..."
    
    ssh -o StrictHostKeyChecking=no ubuntu@$node '
        # Remove ALL Docker-related repository files
        sudo rm -f /etc/apt/sources.list.d/*docker*
        sudo rm -f /etc/apt/sources.list.d/*kubernetes*
        sudo rm -f /etc/apt/keyrings/docker*
        sudo rm -f /etc/apt/keyrings/kubernetes*
        sudo rm -rf /usr/share/keyrings/docker*
        
        # Clean up /etc/apt/sources.list manually for any Docker entries
        sudo sed -i "/docker/d" /etc/apt/sources.list || true
        sudo sed -i "/kubernetes/d" /etc/apt/sources.list || true
        
        # Update apt sources
        sudo apt-get update 2>/dev/null || true
        
        echo "Node $node deep cleaned"
    '
}

main() {
    log "🔥 Starting deep cleanup of all nodes..."
    
    for node in "${MASTER_NODES[@]}" "${WORKER_NODES[@]}" "$LB_NODE" "$STORAGE_NODE"; do
        deep_cleanup_node $node &
    done
    wait
    
    log "✅ Deep cleanup completed!"
}

main "$@"