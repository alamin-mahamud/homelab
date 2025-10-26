# Infrastructure Terraform

Production-ready Terraform configuration for Kubernetes homelab infrastructure.

## Features
- **Multi-node Kubernetes**: 3 masters + 10 workers
- **Dedicated etcd cluster**: 3 nodes for high availability
- **Infrastructure services**: Load balancer, storage, backup
- **Ubuntu 24.04**: Latest LTS with cloud-init
- **Proxmox integration**: Uses existing template (VM ID: 999)

## VM Allocation
```
pve1 (10.1.0.0):
├── 2001-2003: k8s-master-01/02/03    (4 cores, 8GB RAM)
├── 2010-2012: etcd-01/02/03          (2 cores, 4GB RAM)  
├── 2020-2029: k8s-worker-01 to 10    (4 cores, 8GB RAM)
└── 2030-2032: haproxy-lb, truenas, proxmox-backup

Total: 19 VMs
```

## Network Layout
- **Subnet**: 10.1.1.0/24
- **Masters**: 10.1.1.1-3
- **etcd**: 10.1.1.10-12
- **Workers**: 10.1.1.20-29
- **Services**: 10.1.1.30-32

## Usage
```bash
# Initialize
terraform init

# Plan deployment
terraform plan

# Deploy infrastructure
terraform apply

# Generate Ansible inventory
terraform output -raw ansible_inventory > ../ansible/inventory.ini

# Destroy (if needed)
terraform destroy
```

## Customization
Edit `terraform.tfvars` to modify:
- SSH keys
- VM specifications
- Node counts
- Network settings

## Future Enhancements
- [ ] pve2 (Raspberry Pi) support for lightweight workers
- [ ] Multi-node Proxmox cluster distribution
- [ ] GPU node support
- [ ] Storage class configurations