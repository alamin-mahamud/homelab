#!/bin/bash
# Dark Knight Homelab Deployment Script
# Automated deployment of Proxmox-based Kubernetes cluster

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/environments/production"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"

# Default values
ENVIRONMENT="production"
SKIP_TERRAFORM=false
SKIP_ANSIBLE=false
DESTROY_MODE=false
VERBOSE=false

# Logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Help function
show_help() {
    cat << EOF
Dark Knight Homelab Deployment Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -e, --environment ENV    Environment to deploy (default: production)
    -t, --skip-terraform     Skip Terraform deployment
    -a, --skip-ansible       Skip Ansible configuration
    -d, --destroy           Destroy infrastructure instead of creating
    -v, --verbose           Enable verbose output
    -h, --help              Show this help message

EXAMPLES:
    # Full deployment
    $0

    # Deploy only infrastructure
    $0 --skip-ansible

    # Configure existing infrastructure
    $0 --skip-terraform

    # Destroy everything
    $0 --destroy

    # Verbose deployment
    $0 --verbose
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -t|--skip-terraform)
                SKIP_TERRAFORM=true
                shift
                ;;
            -a|--skip-ansible)
                SKIP_ANSIBLE=true
                shift
                ;;
            -d|--destroy)
                DESTROY_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check for required tools
    command -v terraform >/dev/null 2>&1 || missing_tools+=("terraform")
    command -v ansible >/dev/null 2>&1 || missing_tools+=("ansible")
    command -v ssh >/dev/null 2>&1 || missing_tools+=("ssh")
    command -v scp >/dev/null 2>&1 || missing_tools+=("scp")
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing_tools[*]}"
        info "Please install the missing tools and try again."
        exit 1
    fi
    
    # Check for SSH key
    if [[ ! -f ~/.ssh/id_ed25519 ]]; then
        warn "SSH key not found at ~/.ssh/id_ed25519"
        info "Generating new SSH key..."
        ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
    fi
    
    # Check Terraform configuration
    if [[ ! "$SKIP_TERRAFORM" == true ]]; then
        if [[ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]]; then
            error "Terraform variables file not found: $TERRAFORM_DIR/terraform.tfvars"
            info "Please copy terraform.tfvars.example to terraform.tfvars and configure it."
            exit 1
        fi
    fi
    
    log "Prerequisites check completed successfully."
}

# Deploy infrastructure with Terraform
deploy_terraform() {
    if [[ "$SKIP_TERRAFORM" == true ]]; then
        log "Skipping Terraform deployment."
        return
    fi
    
    log "Starting Terraform deployment..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    log "Initializing Terraform..."
    terraform init
    
    if [[ "$DESTROY_MODE" == true ]]; then
        log "Destroying infrastructure..."
        terraform destroy -auto-approve
        log "Infrastructure destroyed successfully."
        return
    fi
    
    # Plan deployment
    log "Planning Terraform deployment..."
    if [[ "$VERBOSE" == true ]]; then
        terraform plan -detailed-exitcode
    else
        terraform plan -detailed-exitcode > /dev/null
    fi
    
    # Apply deployment
    log "Applying Terraform configuration..."
    terraform apply -auto-approve
    
    # Generate inventory
    log "Generating Ansible inventory..."
    if [[ -f "ansible-inventory.ini" ]]; then
        cp ansible-inventory.ini "$ANSIBLE_DIR/inventories/$ENVIRONMENT.ini"
        log "Ansible inventory generated at $ANSIBLE_DIR/inventories/$ENVIRONMENT.ini"
    else
        warn "Ansible inventory file not found. Manual configuration may be required."
    fi
    
    # Display outputs
    log "Terraform deployment completed successfully."
    terraform output
    
    cd - > /dev/null
}

# Configure cluster with Ansible
deploy_ansible() {
    if [[ "$SKIP_ANSIBLE" == true ]]; then
        log "Skipping Ansible configuration."
        return
    fi
    
    if [[ "$DESTROY_MODE" == true ]]; then
        log "Skipping Ansible in destroy mode."
        return
    fi
    
    log "Starting Ansible configuration..."
    
    cd "$ANSIBLE_DIR"
    
    # Check inventory file
    local inventory_file="inventories/$ENVIRONMENT.ini"
    if [[ ! -f "$inventory_file" ]]; then
        error "Ansible inventory file not found: $inventory_file"
        info "Please ensure Terraform has run successfully or create the inventory manually."
        exit 1
    fi
    
    # Wait for VMs to be accessible
    log "Waiting for VMs to be accessible via SSH..."
    local max_retries=60
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        if ansible all -i "$inventory_file" -m ping --one-line > /dev/null 2>&1; then
            log "All VMs are accessible."
            break
        fi
        
        retry_count=$((retry_count + 1))
        info "Waiting for VMs... (attempt $retry_count/$max_retries)"
        sleep 10
    done
    
    if [[ $retry_count -eq $max_retries ]]; then
        error "VMs are not accessible after $max_retries attempts."
        info "Please check the VM status and network configuration."
        exit 1
    fi
    
    # Run Ansible playbooks
    local ansible_opts="-i $inventory_file"
    if [[ "$VERBOSE" == true ]]; then
        ansible_opts="$ansible_opts -v"
    fi
    
    log "Deploying Kubernetes cluster..."
    ansible-playbook $ansible_opts playbooks/site.yml
    
    log "Ansible configuration completed successfully."
    
    cd - > /dev/null
}

# Post-deployment tasks
post_deployment() {
    if [[ "$DESTROY_MODE" == true ]]; then
        log "Cleanup completed."
        return
    fi
    
    log "Running post-deployment tasks..."
    
    # Copy kubeconfig
    local inventory_file="$ANSIBLE_DIR/inventories/$ENVIRONMENT.ini"
    if [[ -f "$inventory_file" ]]; then
        local first_master=$(awk '/\[k8s_first_master\]/{getline; print $2}' "$inventory_file" | cut -d'=' -f2)
        if [[ -n "$first_master" ]]; then
            log "Copying kubeconfig from master node..."
            mkdir -p ~/.kube
            scp -o StrictHostKeyChecking=no "ubuntu@$first_master:/home/ubuntu/.kube/config" ~/.kube/config
            chmod 600 ~/.kube/config
            
            # Test cluster access
            if command -v kubectl >/dev/null 2>&1; then
                log "Testing cluster access..."
                kubectl cluster-info
                kubectl get nodes
            else
                warn "kubectl not found. Please install kubectl to interact with the cluster."
            fi
        fi
    fi
    
    # Display connection information
    log "Deployment completed successfully!"
    info ""
    info "Next steps:"
    info "1. Install kubectl if not already installed"
    info "2. Use 'kubectl get nodes' to verify cluster status"
    info "3. Deploy applications using Helm or kubectl"
    info ""
    info "For monitoring and management:"
    info "- Kubernetes Dashboard: kubectl proxy"
    info "- Grafana: Access via ingress (if configured)"
    info "- Prometheus: Access via ingress (if configured)"
}

# Main function
main() {
    parse_args "$@"
    
    log "Starting Dark Knight Homelab deployment..."
    log "Environment: $ENVIRONMENT"
    log "Skip Terraform: $SKIP_TERRAFORM"
    log "Skip Ansible: $SKIP_ANSIBLE"
    log "Destroy Mode: $DESTROY_MODE"
    
    check_prerequisites
    deploy_terraform
    deploy_ansible
    post_deployment
    
    log "Deployment process completed!"
}

# Trap errors
trap 'error "Script failed at line $LINENO"' ERR

# Run main function
main "$@"