# Quick Start Guide

Get your Dark Knight homelab running in 30 minutes with this streamlined deployment guide.

## 🎯 Overview

This guide will help you deploy:
- 3 Kubernetes master nodes (HA control plane)
- 3 Kubernetes worker nodes  
- 1 HAProxy load balancer
- 1 NFS storage server (optional)

## 🔧 Prerequisites

### Hardware Requirements
- **Minimum**: 64GB RAM, 1TB storage, virtualization support
- **Recommended**: 128GB RAM, 2TB NVMe SSD
- **Proxmox VE 8.x** installed and configured

### Software Requirements
```bash
# Install required tools (Ubuntu/Debian)
sudo apt update
sudo apt install -y terraform ansible openssh-client git

# Or on macOS with Homebrew
brew install terraform ansible git
```

### Access Requirements
- Proxmox API access (token-based authentication)
- SSH access to Proxmox host
- Ubuntu 22.04 cloud-init template (see [template creation](#vm-template-setup))

## 🚀 Quick Deployment

### 1. Clone Repository
```bash
git clone https://github.com/amir-parvin-group/dark-knight.git
cd dark-knight/homelab
```

### 2. Configure Variables
```bash
# Copy and edit Terraform variables
cp terraform/environments/production/terraform.tfvars.example terraform/environments/production/terraform.tfvars

# Edit the configuration
vim terraform/environments/production/terraform.tfvars
```

**Required Configuration:**
```hcl
# Proxmox API Configuration
proxmox_api_url          = "https://YOUR_PROXMOX_IP:8006/api2/json"
proxmox_api_token_id     = "terraform@pam!terraform"
proxmox_api_token_secret = "your-secret-token-here"

# Network Configuration  
network_gateway = "10.0.0.1"
network_dns     = ["10.0.0.1", "1.1.1.1"]

# SSH Key (paste your public key)
ssh_public_keys = [
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExample your-key@homelab"
]
```

### 3. Deploy Everything
```bash
# Run the automated deployment script
./scripts/deploy.sh

# Or deploy manually:
# 1. Deploy infrastructure
cd terraform/environments/production
terraform init && terraform apply

# 2. Configure cluster  
cd ../../../ansible
ansible-playbook -i inventories/production.ini playbooks/site.yml
```

### 4. Access Your Cluster
```bash
# Copy kubeconfig (automatically done by deploy script)
mkdir -p ~/.kube
kubectl cluster-info
kubectl get nodes
```

## 📋 VM Template Setup

Create an Ubuntu 22.04 cloud-init template on Proxmox:

```bash
# On Proxmox host, run:
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
qm create 9000 --name ubuntu-2204-cloudinit --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9000 jammy-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1
qm template 9000
```

## 🎛️ Configuration Options

### Cluster Sizing
```hcl
# Customize node counts
master_count = 3     # HA control plane
worker_count = 3     # Application nodes
deploy_storage = true # NFS server
```

### Resource Allocation
```hcl
# Master nodes
master_cores = 4
master_memory = 8192
master_disk_size = "100G"

# Worker nodes  
worker_cores = 4
worker_memory = 16384
worker_disk_size = "200G"
```

### Network Configuration
```hcl
k8s_network_cidr = "10.2.0.0/24"    # VM network
k8s_pod_subnet = "10.244.0.0/16"    # Pod network
k8s_service_subnet = "10.96.0.0/12" # Service network
```

## ✅ Verification Steps

### 1. Check Infrastructure
```bash
# Verify VMs are running
terraform output

# Test SSH connectivity
ansible all -i ansible/inventories/production.ini -m ping
```

### 2. Validate Kubernetes
```bash
# Check cluster status
kubectl get nodes -o wide
kubectl get pods -A

# Verify networking
kubectl run test-pod --image=busybox --rm -it -- nslookup kubernetes.default
```

### 3. Test Load Balancer
```bash
# Check HAProxy status
curl http://<lb-ip>:8080/stats
```

## 🔧 Common Issues

### VM Template Missing
```bash
# Error: template 'ubuntu-2204-cloudinit' not found
# Solution: Create the template (see VM Template Setup above)
```

### SSH Connection Refused  
```bash
# Wait for cloud-init to complete
ssh ubuntu@<vm-ip> 'cloud-init status --wait'
```

### Kubernetes API Unreachable
```bash
# Check load balancer status
systemctl status haproxy

# Verify master nodes
kubectl get cs
```

## 🎯 Next Steps

Once your cluster is running:

1. **Install Applications**: Use Helm or kubectl to deploy services
2. **Configure Ingress**: Set up NGINX Ingress Controller  
3. **Enable Monitoring**: Deploy Prometheus and Grafana
4. **Set Up Backups**: Configure Velero for disaster recovery

## 📚 Advanced Configuration

- [Detailed Installation Guide](./installation/) - In-depth deployment options
- [Kubernetes Configuration](./kubernetes/) - Platform customization
- [Monitoring Setup](./monitoring/) - Observability stack
- [Security Hardening](./security/) - Production security measures

## 💡 Pro Tips

- **Resource Planning**: Start with fewer workers and scale up as needed
- **Network Segmentation**: Use VLANs for better security isolation
- **Storage Strategy**: Consider Longhorn for distributed storage
- **Backup Schedule**: Set up automated backups from day one
- **Documentation**: Keep your `terraform.tfvars` in a secure, versioned location

---
*Deployment time: ~30 minutes | Cluster ready for production workloads*