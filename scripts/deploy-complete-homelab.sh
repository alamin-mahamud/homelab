#!/bin/bash

# Complete Homelab Deployment Script
# Orchestrates the full deployment process

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
LOG_FILE="$SCRIPT_DIR/deployment.log"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

banner() {
    echo -e "${BLUE}${BOLD}" | tee -a "$LOG_FILE"
    echo "================================================================" | tee -a "$LOG_FILE"
    echo "    🏠 COMPLETE HOMELAB DEPLOYMENT - DARK KNIGHT PROJECT 🏠" | tee -a "$LOG_FILE"
    echo "================================================================" | tee -a "$LOG_FILE"
    echo -e "${NC}" | tee -a "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    local missing_tools=()
    
    command -v ansible >/dev/null 2>&1 || missing_tools+=("ansible")
    command -v ssh >/dev/null 2>&1 || missing_tools+=("ssh")
    command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
    command -v helm >/dev/null 2>&1 || missing_tools+=("helm")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
    fi
    
    # Test SSH connectivity
    if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@10.1.0.0 'echo "SSH OK"' >/dev/null 2>&1; then
        error "Cannot SSH to Proxmox host (10.1.0.0)"
    fi
    
    if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@10.1.0.1 'echo "SSH OK"' >/dev/null 2>&1; then
        error "Cannot SSH to Raspberry Pi (10.1.0.1)"
    fi
    
    log "✅ Prerequisites check passed"
}

# Deploy VMs
deploy_vms() {
    log "🚀 Phase 1: Deploying VMs on Proxmox cluster..."
    
    chmod +x "$SCRIPT_DIR/create-k8s-vms.sh"
    "$SCRIPT_DIR/create-k8s-vms.sh" || error "VM deployment failed"
    
    log "⏳ Waiting for VMs to fully boot..."
    sleep 60
    
    log "✅ VM deployment completed"
}

# Setup Kubernetes cluster
setup_kubernetes() {
    log "🔧 Phase 2: Setting up Kubernetes cluster..."
    
    # Wait for VMs to be accessible
    local max_retries=10
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if ansible all -i "$SCRIPT_DIR/inventory.ini" -m ping --timeout=10 >/dev/null 2>&1; then
            break
        fi
        retry_count=$((retry_count + 1))
        warning "VMs not yet accessible, retrying ($retry_count/$max_retries)..."
        sleep 30
    done
    
    if [ $retry_count -eq $max_retries ]; then
        error "VMs not accessible after $max_retries attempts"
    fi
    
    # Install Python on all nodes (required for Ansible)
    log "Installing Python on all nodes..."
    ansible all -i "$SCRIPT_DIR/inventory.ini" -m raw -a "apt-get update && apt-get install -y python3"
    
    # Run Kubernetes setup playbook
    log "Running Kubernetes setup playbook..."
    ansible-playbook -i "$SCRIPT_DIR/inventory.ini" "$SCRIPT_DIR/setup-k8s-cluster.yml" || error "Kubernetes setup failed"
    
    # Copy kubeconfig from master node
    log "Copying kubeconfig to jump host..."
    mkdir -p ~/.kube
    scp -o StrictHostKeyChecking=no ubuntu@10.2.0.11:~/.kube/config ~/.kube/config
    chmod 600 ~/.kube/config
    
    # Test cluster
    if kubectl cluster-info >/dev/null 2>&1; then
        log "✅ Kubernetes cluster setup completed"
    else
        error "Kubernetes cluster not accessible"
    fi
}

# Deploy services
deploy_services() {
    log "📦 Phase 3: Deploying homelab services..."
    
    chmod +x "$SCRIPT_DIR/deploy-homelab-services.sh"
    "$SCRIPT_DIR/deploy-homelab-services.sh" || error "Services deployment failed"
    
    log "✅ Homelab services deployment completed"
}

# Setup Raspberry Pi
setup_raspberry_pi() {
    log "🥧 Phase 4: Configuring Raspberry Pi for lightweight services..."
    
    chmod +x "$SCRIPT_DIR/setup-raspberry-pi.sh"
    "$SCRIPT_DIR/setup-raspberry-pi.sh" || error "Raspberry Pi setup failed"
    
    log "✅ Raspberry Pi configuration completed"
}

# Run tests
run_tests() {
    log "🧪 Phase 5: Running deployment tests..."
    
    chmod +x "$SCRIPT_DIR/test-deployment.sh"
    "$SCRIPT_DIR/test-deployment.sh" || warning "Some tests failed, check the logs"
    
    log "✅ Testing phase completed"
}

# Generate summary
generate_summary() {
    log "📋 Generating deployment summary..."
    
    local summary_file="$SCRIPT_DIR/deployment-summary.txt"
    
    cat > "$summary_file" <<EOF
=================================================================
🏠 HOMELAB DEPLOYMENT SUMMARY - $(date)
=================================================================

📊 INFRASTRUCTURE:
==================
Proxmox Cluster:
  • pve1 (10.1.0.0) - Main node with K8s cluster
  • pve2 (10.1.0.1) - Raspberry Pi with lightweight services

Kubernetes Cluster:
  • 3 Control Plane nodes (10.2.0.11-13)
  • 7 Worker nodes (10.2.0.21-27)
  • 1 Load Balancer (10.2.0.10)
  • 1 Storage node (10.2.0.30)
  Total VMs: 12

🚀 SERVICES DEPLOYED:
=====================
Kubernetes Services (Main Cluster):
$(kubectl get svc -A | grep LoadBalancer | awk '{print "  • " $2 " (" $1 "): " $5}')

Raspberry Pi Services:
  • Pi-hole DNS (10.1.0.1:8080)
  • Heimdall Dashboard (10.1.0.1:8082)
  • Uptime Kuma (10.1.0.1:3001)
  • Nginx Proxy Manager (10.1.0.1:81)
  • Zigbee2MQTT (10.1.0.1:8081)
  • WireGuard VPN (10.1.0.1:51820)
  • MQTT Broker (10.1.0.1:1883)
  • Node Exporter (10.1.0.1:9100)

📈 MONITORING:
==============
  • Prometheus: $(kubectl get svc prometheus -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):9090
  • Grafana: $(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):3000
  • Longhorn UI: Access via port-forward
  • Pi-hole metrics integrated

🔐 DEFAULT CREDENTIALS:
=======================
  • Grafana: admin/admin
  • Pi-hole: admin/admin123
  • Nextcloud: admin/admin123
  • Nginx Proxy Manager: admin@example.com/changeme

🌐 DNS CONFIGURATION:
=====================
Primary DNS: 10.1.0.1 (Pi-hole)
Domain: homelab.local

All services accessible via .homelab.local domains when using Pi-hole DNS.

📁 FILES CREATED:
=================
  • K8s manifests: $SCRIPT_DIR/k8s-manifests/
  • Ansible inventory: $SCRIPT_DIR/inventory.ini
  • Service check script: $SCRIPT_DIR/check-pi-services.sh
  • Deployment logs: $LOG_FILE

🎯 NEXT STEPS:
==============
1. Configure DNS on your network to use 10.1.0.1
2. Access Grafana and import additional dashboards
3. Configure Plex media libraries
4. Set up Home Assistant integrations
5. Configure backup strategies

🚀 DEPLOYMENT COMPLETED SUCCESSFULLY! 🚀
EOF

    cat "$summary_file" | tee -a "$LOG_FILE"
    
    info "📋 Summary saved to: $summary_file"
}

# Main deployment function
main() {
    banner
    
    log "🚀 Starting complete homelab deployment..."
    log "📝 Deployment log: $LOG_FILE"
    
    # Create deployment directory
    mkdir -p "$SCRIPT_DIR/k8s-manifests"
    
    # Run deployment phases
    check_prerequisites
    deploy_vms
    setup_kubernetes
    deploy_services
    setup_raspberry_pi
    run_tests
    generate_summary
    
    echo ""
    echo -e "${GREEN}${BOLD}🎉 HOMELAB DEPLOYMENT COMPLETED SUCCESSFULLY! 🎉${NC}"
    echo ""
    echo "Your Dark Knight homelab is now running with:"
    echo "• High-availability Kubernetes cluster (12 nodes)"
    echo "• Complete monitoring stack with Prometheus & Grafana"
    echo "• Media services with Plex and Nextcloud"
    echo "• Home automation with Home Assistant"
    echo "• Network services with Pi-hole and VPN"
    echo "• Distributed storage with Longhorn"
    echo ""
    echo "Check the deployment summary for all access URLs and credentials."
    
    log "🏠 Dark Knight Homelab deployment completed at $(date)"
}

# Error handling
trap 'error "Deployment failed at line $LINENO"' ERR

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi