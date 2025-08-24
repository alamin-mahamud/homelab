#!/bin/bash
# HomeLab Complete Deployment Script
# This script orchestrates the entire homelab deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/deployment_${TIMESTAMP}.log"

# Create log directory
mkdir -p "${LOG_DIR}"

# Logging function
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
    
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
}

# Error handler
error_handler() {
    local line_no=$1
    log ERROR "Deployment failed at line ${line_no}"
    log ERROR "Check log file: ${LOG_FILE}"
    exit 1
}

trap 'error_handler ${LINENO}' ERR

# Check prerequisites
check_prerequisites() {
    log INFO "Checking prerequisites..."
    
    local tools=("terraform" "ansible" "kubectl" "helm" "jq" "ssh")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log ERROR "Missing required tools: ${missing_tools[*]}"
        log INFO "Please install missing tools and try again"
        exit 1
    fi
    
    # Check SSH key
    if [ ! -f ~/.ssh/homelab_rsa ]; then
        log WARNING "SSH key not found. Generating new key..."
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/homelab_rsa -N "" -C "homelab@deployment"
        log SUCCESS "SSH key generated"
    fi
    
    # Check Proxmox connectivity
    log INFO "Checking Proxmox connectivity..."
    if ! ping -c 1 10.1.0.0 &> /dev/null; then
        log ERROR "Cannot reach Proxmox host (10.1.0.0)"
        exit 1
    fi
    
    log SUCCESS "All prerequisites met"
}

# Phase 1: Infrastructure Provisioning with Terraform
phase1_infrastructure() {
    log INFO "=== Phase 1: Infrastructure Provisioning ==="
    
    cd "${PROJECT_ROOT}/terraform/environments/production"
    
    # Check for terraform.tfvars
    if [ ! -f terraform.tfvars ]; then
        log WARNING "terraform.tfvars not found. Creating from template..."
        cp terraform.tfvars.example terraform.tfvars
        log WARNING "Please edit terraform.tfvars with your configuration"
        read -p "Press Enter when ready to continue..."
    fi
    
    log INFO "Initializing Terraform..."
    terraform init -upgrade
    
    log INFO "Planning infrastructure changes..."
    terraform plan -out=tfplan
    
    read -p "Review the plan above. Deploy infrastructure? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log WARNING "Infrastructure deployment cancelled"
        return 1
    fi
    
    log INFO "Applying Terraform configuration..."
    terraform apply tfplan
    
    # Generate Ansible inventory
    log INFO "Generating Ansible inventory..."
    terraform output -raw ansible_inventory > "${PROJECT_ROOT}/ansible/inventories/terraform.ini"
    
    log SUCCESS "Infrastructure provisioned successfully"
    
    # Wait for VMs to be ready
    log INFO "Waiting for VMs to be ready..."
    sleep 30
}

# Phase 2: Kubernetes Cluster Deployment
phase2_kubernetes() {
    log INFO "=== Phase 2: Kubernetes Cluster Deployment ==="
    
    cd "${PROJECT_ROOT}/ansible"
    
    log INFO "Testing connectivity to all nodes..."
    ansible -i inventories/terraform.ini all -m ping
    
    log INFO "Deploying Kubernetes cluster..."
    ansible-playbook -i inventories/terraform.ini playbooks/k8s/complete-deploy.yaml
    
    # Get kubeconfig
    log INFO "Retrieving kubeconfig..."
    scp ubuntu@$(terraform -chdir="${PROJECT_ROOT}/terraform/environments/production" output -json k8s_masters | jq -r '.["k8s-master-01"].ip'):/home/ubuntu/.kube/config ~/.kube/config
    
    # Verify cluster
    log INFO "Verifying cluster status..."
    kubectl get nodes
    kubectl get pods -A
    
    log SUCCESS "Kubernetes cluster deployed successfully"
}

# Phase 3: Storage and Networking
phase3_storage_network() {
    log INFO "=== Phase 3: Storage and Networking Setup ==="
    
    # Deploy Longhorn
    log INFO "Deploying Longhorn storage..."
    kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/longhorn.yaml
    
    # Wait for Longhorn
    kubectl wait --for=condition=available --timeout=600s deployment/longhorn-ui -n longhorn-system
    
    # Deploy MetalLB
    log INFO "Deploying MetalLB load balancer..."
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
    
    # Configure IP pool
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
    
    # Deploy NGINX Ingress
    log INFO "Deploying NGINX Ingress Controller..."
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx --create-namespace \
        --set controller.service.type=LoadBalancer
    
    log SUCCESS "Storage and networking configured"
}

# Phase 4: Monitoring Stack
phase4_monitoring() {
    log INFO "=== Phase 4: Monitoring Stack Deployment ==="
    
    # Deploy Prometheus Stack
    log INFO "Deploying kube-prometheus-stack..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    helm install monitoring prometheus-community/kube-prometheus-stack \
        --namespace monitoring --create-namespace \
        --set grafana.adminPassword=admin123 \
        --set prometheus.prometheusSpec.retention=30d \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=longhorn \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi
    
    # Get Grafana URL
    GRAFANA_IP=$(kubectl get svc -n monitoring monitoring-grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    log SUCCESS "Grafana available at: http://${GRAFANA_IP}"
    
    log SUCCESS "Monitoring stack deployed"
}

# Phase 5: HomeLab Services
phase5_services() {
    log INFO "=== Phase 5: HomeLab Services Deployment ==="
    
    # Apply all service manifests
    kubectl apply -f "${SCRIPT_DIR}/k8s-manifests/"
    
    log SUCCESS "HomeLab services deployed"
}

# Phase 6: Testing
phase6_testing() {
    log INFO "=== Phase 6: Deployment Testing ==="
    
    "${SCRIPT_DIR}/test-deployment.sh"
    
    log SUCCESS "All tests passed"
}

# Generate documentation
generate_docs() {
    log INFO "Generating deployment documentation..."
    
    cat > "${LOG_DIR}/deployment_summary_${TIMESTAMP}.md" <<EOF
# HomeLab Deployment Summary
Generated: $(date)

## Infrastructure
- Kubernetes Masters: $(kubectl get nodes -l node-role.kubernetes.io/control-plane -o name | wc -l)
- Kubernetes Workers: $(kubectl get nodes -l node-role.kubernetes.io/worker -o name | wc -l)
- Total Pods: $(kubectl get pods -A --no-headers | wc -l)

## Access URLs
$(kubectl get svc -A | grep LoadBalancer | awk '{print "- " $2 ": http://" $5}')

## Storage
$(kubectl get storageclass)

## Logs
- Deployment Log: ${LOG_FILE}

## Next Steps
1. Configure DNS entries for services
2. Set up SSL certificates
3. Configure backup schedules
4. Set up monitoring alerts
EOF
    
    log SUCCESS "Documentation generated: ${LOG_DIR}/deployment_summary_${TIMESTAMP}.md"
}

# Main execution
main() {
    log INFO "Starting HomeLab deployment..."
    log INFO "Log file: ${LOG_FILE}"
    
    check_prerequisites
    
    # Interactive mode
    if [ "${1:-}" == "--interactive" ]; then
        PS3="Select deployment phase: "
        options=("Full Deployment" "Infrastructure Only" "Kubernetes Only" "Storage/Network Only" "Monitoring Only" "Services Only" "Testing Only" "Quit")
        
        select opt in "${options[@]}"; do
            case $opt in
                "Full Deployment")
                    phase1_infrastructure
                    phase2_kubernetes
                    phase3_storage_network
                    phase4_monitoring
                    phase5_services
                    phase6_testing
                    generate_docs
                    break
                    ;;
                "Infrastructure Only")
                    phase1_infrastructure
                    break
                    ;;
                "Kubernetes Only")
                    phase2_kubernetes
                    break
                    ;;
                "Storage/Network Only")
                    phase3_storage_network
                    break
                    ;;
                "Monitoring Only")
                    phase4_monitoring
                    break
                    ;;
                "Services Only")
                    phase5_services
                    break
                    ;;
                "Testing Only")
                    phase6_testing
                    break
                    ;;
                "Quit")
                    break
                    ;;
                *) 
                    echo "Invalid option"
                    ;;
            esac
        done
    else
        # Full deployment
        phase1_infrastructure
        phase2_kubernetes
        phase3_storage_network
        phase4_monitoring
        phase5_services
        phase6_testing
        generate_docs
    fi
    
    log SUCCESS "HomeLab deployment completed successfully!"
    log INFO "Check deployment summary: ${LOG_DIR}/deployment_summary_${TIMESTAMP}.md"
}

# Run main function
main "$@"