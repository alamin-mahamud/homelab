#!/bin/bash

# Cleanup Stopped VMs and Containers Script
# Removes all stopped VMs and containers from Proxmox cluster

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

PROXMOX_HOSTS=("10.1.0.0" "10.1.0.1")
PRESERVE_VMS=("999" "777" "701")  # Keep template VM, win7-retro-gaming, and VM 701
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Usage: $0 [--dry-run]"
            exit 1
            ;;
    esac
done

# Function to cleanup VMs on a host
cleanup_vms() {
    local host=$1
    local host_name=""
    
    if [[ "$host" == "10.1.0.0" ]]; then
        host_name="pve1 (Main Proxmox)"
    else
        host_name="pve2 (Raspberry Pi)"
    fi
    
    log "Cleaning up VMs on $host_name..."
    
    # Get list of stopped VMs
    local stopped_vms=($(ssh root@$host 'qm list | grep stopped | awk "{print \$1}"' 2>/dev/null || echo ""))
    
    if [ ${#stopped_vms[@]} -eq 0 ]; then
        log "No stopped VMs found on $host_name"
        return
    fi
    
    log "Found ${#stopped_vms[@]} stopped VMs on $host_name"
    
    for vmid in "${stopped_vms[@]}"; do
        # Check if VM should be preserved
        local preserve=false
        for preserve_id in "${PRESERVE_VMS[@]}"; do
            if [[ "$vmid" == "$preserve_id" ]]; then
                preserve=true
                break
            fi
        done
        
        if [[ "$preserve" == "true" ]]; then
            warning "Preserving VM $vmid (template/important VM)"
            continue
        fi
        
        # Get VM name for display
        local vm_name=$(ssh root@$host "qm config $vmid | grep '^name:' | cut -d' ' -f2" 2>/dev/null || echo "unknown")
        
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "  [DRY-RUN] Would delete VM $vmid ($vm_name) on $host_name"
        else
            log "Deleting VM $vmid ($vm_name) on $host_name..."
            
            # Stop VM if somehow still running
            ssh root@$host "qm stop $vmid" 2>/dev/null || true
            sleep 2
            
            # Delete VM and its disks
            if ssh root@$host "qm destroy $vmid --destroy-unreferenced-disks 1 --purge 1" 2>/dev/null; then
                log "✅ Successfully deleted VM $vmid ($vm_name)"
            else
                warning "Failed to delete VM $vmid ($vm_name)"
            fi
        fi
    done
}

# Function to cleanup containers on a host
cleanup_containers() {
    local host=$1
    local host_name=""
    
    if [[ "$host" == "10.1.0.0" ]]; then
        host_name="pve1 (Main Proxmox)"
    else
        host_name="pve2 (Raspberry Pi)"
    fi
    
    log "Cleaning up containers on $host_name..."
    
    # Get list of stopped containers
    local stopped_containers=($(ssh root@$host 'pct list | grep stopped | awk "{print \$1}"' 2>/dev/null || echo ""))
    
    if [ ${#stopped_containers[@]} -eq 0 ]; then
        log "No stopped containers found on $host_name"
        return
    fi
    
    log "Found ${#stopped_containers[@]} stopped containers on $host_name"
    
    for ctid in "${stopped_containers[@]}"; do
        # Get container name for display
        local ct_name=$(ssh root@$host "pct config $ctid | grep '^hostname:' | cut -d' ' -f2" 2>/dev/null || echo "unknown")
        
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "  [DRY-RUN] Would delete container $ctid ($ct_name) on $host_name"
        else
            log "Deleting container $ctid ($ct_name) on $host_name..."
            
            # Stop container if somehow still running
            ssh root@$host "pct stop $ctid" 2>/dev/null || true
            sleep 2
            
            # Delete container
            if ssh root@$host "pct destroy $ctid --destroy-unreferenced-disks 1 --purge 1" 2>/dev/null; then
                log "✅ Successfully deleted container $ctid ($ct_name)"
            else
                warning "Failed to delete container $ctid ($ct_name)"
            fi
        fi
    done
}

# Function to show space freed
show_space_freed() {
    local host=$1
    local host_name=""
    
    if [[ "$host" == "10.1.0.0" ]]; then
        host_name="pve1"
    else
        host_name="pve2"
    fi
    
    log "Storage usage on $host_name:"
    ssh root@$host 'df -h | grep -E "(local-lvm|Avail)" | head -2'
}

# Main execution
main() {
    if [[ "$DRY_RUN" == "true" ]]; then
        warning "DRY RUN MODE - No VMs will be actually deleted"
        echo ""
    fi
    
    log "Starting cleanup of stopped VMs and containers..."
    log "Preserving VMs: ${PRESERVE_VMS[*]}"
    echo ""
    
    # Show current status
    log "Current VM/Container status:"
    for host in "${PROXMOX_HOSTS[@]}"; do
        local host_name="pve1"
        [[ "$host" == "10.1.0.1" ]] && host_name="pve2"
        
        echo "--- $host_name ($host) ---"
        ssh root@$host 'echo "VMs:"; qm list | grep -c stopped || echo "0"; echo "Containers:"; pct list | grep -c stopped || echo "0"' 2>/dev/null
        echo ""
    done
    
    # Cleanup each host
    for host in "${PROXMOX_HOSTS[@]}"; do
        cleanup_vms "$host"
        cleanup_containers "$host"
        echo ""
    done
    
    if [[ "$DRY_RUN" == "false" ]]; then
        log "Cleanup completed! Storage freed:"
        for host in "${PROXMOX_HOSTS[@]}"; do
            show_space_freed "$host"
            echo ""
        done
        
        log "🎉 Cleanup process completed successfully!"
        echo ""
        echo "Summary:"
        echo "• All stopped VMs have been removed (except templates)"
        echo "• All stopped containers have been removed"
        echo "• Storage space has been freed for new deployments"
        echo "• Template VM 999 has been preserved for future use"
    fi
}

# Run main function
main "$@"