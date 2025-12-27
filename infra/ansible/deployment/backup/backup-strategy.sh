#!/bin/bash
# Comprehensive Backup Strategy for HomeLab
# Implements automated backups for all critical components

set -euo pipefail

# Configuration
BACKUP_BASE_DIR="/opt/homelab-backups"
LOG_DIR="${BACKUP_BASE_DIR}/logs"
RETENTION_DAYS=30
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)
            echo -e "${BLUE}[INFO]${NC} ${message}"
            ;;
        SUCCESS)
            echo -e "${GREEN}[SUCCESS]${NC} ${message}"
            ;;
        WARNING)
            echo -e "${YELLOW}[WARNING]${NC} ${message}"
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} ${message}"
            ;;
    esac
    
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_DIR}/backup_${TIMESTAMP}.log"
}

# Setup backup directories
setup_backup_dirs() {
    log INFO "Setting up backup directory structure..."
    
    mkdir -p "${BACKUP_BASE_DIR}"/{kubernetes,proxmox,databases,configs,pi-services,logs}
    
    # Create retention policy script
    cat > "${BACKUP_BASE_DIR}/cleanup-old-backups.sh" << 'EOF'
#!/bin/bash
RETENTION_DAYS=${1:-30}
BACKUP_BASE_DIR="/opt/homelab-backups"

find "${BACKUP_BASE_DIR}" -name "*.tar.gz" -mtime +${RETENTION_DAYS} -delete
find "${BACKUP_BASE_DIR}" -name "*.sql" -mtime +${RETENTION_DAYS} -delete
find "${BACKUP_BASE_DIR}/logs" -name "*.log" -mtime +7 -delete

echo "Cleaned up backups older than ${RETENTION_DAYS} days"
EOF
    
    chmod +x "${BACKUP_BASE_DIR}/cleanup-old-backups.sh"
    
    log SUCCESS "Backup directory structure created"
}

# Backup Kubernetes cluster
backup_kubernetes() {
    log INFO "Backing up Kubernetes cluster..."
    
    local k8s_backup_dir="${BACKUP_BASE_DIR}/kubernetes/k8s_${TIMESTAMP}"
    mkdir -p "${k8s_backup_dir}"
    
    # Backup cluster resources
    kubectl get all -A -o yaml > "${k8s_backup_dir}/all-resources.yaml"
    kubectl get pv,pvc -A -o yaml > "${k8s_backup_dir}/storage.yaml"
    kubectl get configmap,secret -A -o yaml > "${k8s_backup_dir}/configs-secrets.yaml"
    kubectl get crd -o yaml > "${k8s_backup_dir}/custom-resources.yaml"
    
    # Backup ETCD (if accessible)
    if kubectl get pods -n kube-system -l component=etcd --no-headers | head -1 >/dev/null 2>&1; then
        local etcd_pod=$(kubectl get pods -n kube-system -l component=etcd --no-headers | head -1 | awk '{print $1}')
        kubectl exec -n kube-system "${etcd_pod}" -- etcdctl \
            --endpoints=https://127.0.0.1:2379 \
            --cacert=/etc/kubernetes/pki/etcd/ca.crt \
            --cert=/etc/kubernetes/pki/etcd/server.crt \
            --key=/etc/kubernetes/pki/etcd/server.key \
            snapshot save /tmp/etcd-backup.db
        
        kubectl cp "kube-system/${etcd_pod}:/tmp/etcd-backup.db" "${k8s_backup_dir}/etcd-backup.db"
        log SUCCESS "ETCD backup completed"
    fi
    
    # Backup Helm releases
    helm list -A -o yaml > "${k8s_backup_dir}/helm-releases.yaml"
    
    # Create archive
    tar -czf "${BACKUP_BASE_DIR}/kubernetes/k8s-backup-${TIMESTAMP}.tar.gz" -C "${k8s_backup_dir}" .
    rm -rf "${k8s_backup_dir}"
    
    log SUCCESS "Kubernetes backup completed"
}

# Backup Velero (if installed)
backup_velero() {
    if kubectl get ns velero >/dev/null 2>&1; then
        log INFO "Creating Velero backup..."
        
        velero backup create "homelab-${TIMESTAMP}" \
            --include-namespaces=media,productivity,automation,network,management \
            --wait
        
        log SUCCESS "Velero backup created: homelab-${TIMESTAMP}"
    else
        log WARNING "Velero not installed, skipping Velero backup"
    fi
}

# Backup Proxmox VMs
backup_proxmox() {
    log INFO "Backing up Proxmox VMs..."
    
    local proxmox_backup_dir="${BACKUP_BASE_DIR}/proxmox/proxmox_${TIMESTAMP}"
    mkdir -p "${proxmox_backup_dir}"
    
    # Get VM configurations
    ssh root@10.1.0.0 'for vm in $(qm list | awk "NR>1 {print \$1}"); do qm config $vm > /tmp/vm-${vm}.conf; done'
    ssh root@10.1.0.0 'tar -czf /tmp/vm-configs.tar.gz /tmp/vm-*.conf'
    scp root@10.1.0.0:/tmp/vm-configs.tar.gz "${proxmox_backup_dir}/"
    
    # Get cluster configuration
    ssh root@10.1.0.0 'cp -r /etc/pve /tmp/pve-config'
    ssh root@10.1.0.0 'tar -czf /tmp/pve-config.tar.gz /tmp/pve-config'
    scp root@10.1.0.0:/tmp/pve-config.tar.gz "${proxmox_backup_dir}/"
    
    # Cleanup remote temp files
    ssh root@10.1.0.0 'rm -f /tmp/vm-*.conf /tmp/vm-configs.tar.gz /tmp/pve-config.tar.gz'
    ssh root@10.1.0.0 'rm -rf /tmp/pve-config'
    
    # Create full backup using vzdump for critical VMs
    log INFO "Creating full VM backups (may take time)..."
    ssh root@10.1.0.0 "vzdump --all --compress lzo --storage local --mode snapshot --exclude 701" || log WARNING "Some VM backups may have failed"
    
    # Archive configurations
    tar -czf "${BACKUP_BASE_DIR}/proxmox/proxmox-config-${TIMESTAMP}.tar.gz" -C "${proxmox_backup_dir}" .
    rm -rf "${proxmox_backup_dir}"
    
    log SUCCESS "Proxmox backup completed"
}

# Backup databases
backup_databases() {
    log INFO "Backing up databases..."
    
    local db_backup_dir="${BACKUP_BASE_DIR}/databases"
    
    # PostgreSQL backups (if running)
    if kubectl get pods -A -l app=postgresql --no-headers >/dev/null 2>&1; then
        local pg_pods=($(kubectl get pods -A -l app=postgresql --no-headers | awk '{print $2":"$1}'))
        for pod_info in "${pg_pods[@]}"; do
            local pod=$(echo "$pod_info" | cut -d: -f1)
            local namespace=$(echo "$pod_info" | cut -d: -f2)
            
            kubectl exec -n "$namespace" "$pod" -- pg_dumpall -c -U postgres > "${db_backup_dir}/postgresql-${namespace}-${TIMESTAMP}.sql"
        done
        log SUCCESS "PostgreSQL backups completed"
    fi
    
    # MySQL backups (if running)
    if kubectl get pods -A -l app=mysql --no-headers >/dev/null 2>&1; then
        local mysql_pods=($(kubectl get pods -A -l app=mysql --no-headers | awk '{print $2":"$1}'))
        for pod_info in "${mysql_pods[@]}"; do
            local pod=$(echo "$pod_info" | cut -d: -f1)
            local namespace=$(echo "$pod_info" | cut -d: -f2)
            
            kubectl exec -n "$namespace" "$pod" -- mysqldump --all-databases -u root > "${db_backup_dir}/mysql-${namespace}-${TIMESTAMP}.sql"
        done
        log SUCCESS "MySQL backups completed"
    fi
}

# Backup Raspberry Pi services
backup_pi_services() {
    log INFO "Backing up Raspberry Pi services..."
    
    local pi_backup_dir="${BACKUP_BASE_DIR}/pi-services/pi_${TIMESTAMP}"
    mkdir -p "${pi_backup_dir}"
    
    # Backup service configurations and data
    ssh root@10.1.0.1 'cd /opt/homelab-services && tar -czf /tmp/pi-services-backup.tar.gz .'
    scp root@10.1.0.1:/tmp/pi-services-backup.tar.gz "${pi_backup_dir}/"
    
    # Backup system configuration
    ssh root@10.1.0.1 'tar -czf /tmp/pi-system-config.tar.gz /etc/systemd /etc/cron* /etc/network /home/pi/.config'
    scp root@10.1.0.1:/tmp/pi-system-config.tar.gz "${pi_backup_dir}/"
    
    # Cleanup remote files
    ssh root@10.1.0.1 'rm -f /tmp/pi-*.tar.gz'
    
    # Archive
    tar -czf "${BACKUP_BASE_DIR}/pi-services/pi-backup-${TIMESTAMP}.tar.gz" -C "${pi_backup_dir}" .
    rm -rf "${pi_backup_dir}"
    
    log SUCCESS "Raspberry Pi backup completed"
}

# Backup configurations
backup_configs() {
    log INFO "Backing up configuration files..."
    
    local config_backup_dir="${BACKUP_BASE_DIR}/configs"
    
    # Backup this repository
    tar -czf "${config_backup_dir}/homelab-repo-${TIMESTAMP}.tar.gz" -C "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" . --exclude='.git' --exclude='logs' --exclude='*.log'
    
    # Backup SSH keys and configs
    if [ -d ~/.ssh ]; then
        tar -czf "${config_backup_dir}/ssh-config-${TIMESTAMP}.tar.gz" -C ~/ .ssh
    fi
    
    # Backup kubeconfig
    if [ -f ~/.kube/config ]; then
        cp ~/.kube/config "${config_backup_dir}/kubeconfig-${TIMESTAMP}"
    fi
    
    log SUCCESS "Configuration backup completed"
}

# Verify backups
verify_backups() {
    log INFO "Verifying backup integrity..."
    
    local failed_verifications=0
    
    # Check backup files exist and are not empty
    for backup_file in $(find "${BACKUP_BASE_DIR}" -name "*.tar.gz" -o -name "*.sql" -newer "${LOG_DIR}/backup_${TIMESTAMP}.log" 2>/dev/null); do
        if [ ! -s "$backup_file" ]; then
            log ERROR "Backup file is empty: $backup_file"
            ((failed_verifications++))
        else
            # Test archive integrity
            if [[ "$backup_file" == *.tar.gz ]]; then
                if ! tar -tzf "$backup_file" >/dev/null 2>&1; then
                    log ERROR "Corrupt archive: $backup_file"
                    ((failed_verifications++))
                else
                    log SUCCESS "Verified: $backup_file"
                fi
            fi
        fi
    done
    
    if [ $failed_verifications -eq 0 ]; then
        log SUCCESS "All backup verifications passed"
        return 0
    else
        log ERROR "$failed_verifications backup(s) failed verification"
        return 1
    fi
}

# Sync to remote storage (optional)
sync_remote() {
    if [ -n "${REMOTE_BACKUP_HOST:-}" ]; then
        log INFO "Syncing backups to remote storage..."
        
        rsync -avz --delete "${BACKUP_BASE_DIR}/" "${REMOTE_BACKUP_HOST}:${REMOTE_BACKUP_PATH:-/backups/homelab}/"
        
        log SUCCESS "Remote sync completed"
    else
        log INFO "No remote backup configured (set REMOTE_BACKUP_HOST to enable)"
    fi
}

# Send notifications
send_notification() {
    local status=$1
    local message=$2
    
    if [ -n "${WEBHOOK_URL:-}" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"Homelab Backup ${status}: ${message}\"}" \
            "${WEBHOOK_URL}" >/dev/null 2>&1 || true
    fi
    
    # Email notification (if configured)
    if command -v mail >/dev/null 2>&1 && [ -n "${ADMIN_EMAIL:-}" ]; then
        echo "${message}" | mail -s "Homelab Backup ${status}" "${ADMIN_EMAIL}" || true
    fi
}

# Generate backup report
generate_report() {
    local backup_size=$(du -sh "${BACKUP_BASE_DIR}" | cut -f1)
    local backup_count=$(find "${BACKUP_BASE_DIR}" -name "*.tar.gz" -o -name "*.sql" | wc -l)
    
    cat > "${LOG_DIR}/backup-report-${TIMESTAMP}.md" << EOF
# HomeLab Backup Report
Generated: $(date)

## Summary
- Backup Location: ${BACKUP_BASE_DIR}
- Total Size: ${backup_size}
- Number of Files: ${backup_count}
- Retention: ${RETENTION_DAYS} days

## Components Backed Up
- [x] Kubernetes cluster resources
- [x] Proxmox VM configurations
- [x] Database dumps
- [x] Raspberry Pi services
- [x] Configuration files

## Latest Backups
$(find "${BACKUP_BASE_DIR}" -name "*${TIMESTAMP}*" -exec ls -lh {} \; | awk '{print "- " $9 " (" $5 ")"}')

## Storage Usage
$(du -sh "${BACKUP_BASE_DIR}"/* | awk '{print "- " $2 ": " $1}')

## Next Steps
1. Verify backup integrity
2. Test restore procedures
3. Update retention policy if needed
4. Monitor storage usage
EOF

    log SUCCESS "Backup report generated: ${LOG_DIR}/backup-report-${TIMESTAMP}.md"
}

# Main backup function
main() {
    local start_time=$(date +%s)
    
    log INFO "Starting HomeLab backup process..."
    
    # Setup
    setup_backup_dirs
    
    # Perform backups
    backup_kubernetes
    backup_velero
    backup_proxmox
    backup_databases
    backup_pi_services
    backup_configs
    
    # Verification
    if verify_backups; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local message="Backup completed successfully in ${duration} seconds"
        
        log SUCCESS "$message"
        send_notification "SUCCESS" "$message"
    else
        local message="Backup completed with errors - check logs"
        log ERROR "$message"
        send_notification "ERROR" "$message"
    fi
    
    # Sync and cleanup
    sync_remote
    "${BACKUP_BASE_DIR}/cleanup-old-backups.sh" "${RETENTION_DAYS}"
    
    # Generate report
    generate_report
    
    log SUCCESS "Backup process completed!"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi