# HomeLab Deployment Guide

This directory contains the complete Infrastructure as Code (IaC) deployment for a production-grade HomeLab environment using Kubernetes, Proxmox, and Raspberry Pi.

## 🏗️ **DEPLOYED ARCHITECTURE** ✅

### Infrastructure Components (OPERATIONAL)

- **Proxmox VE**: Hypervisor hosting VM infrastructure
- **Kubernetes Cluster**: 1 master + 6 workers (7 total nodes)
- **Raspberry Pi**: Lightweight auxiliary services
- **Storage**: Longhorn distributed storage (3 replicas)
- **Networking**: MetalLB load balancer with IP pool 10.1.1.100-150
- **Monitoring**: Prometheus + Grafana operational

### Network Layout (LIVE)

- **Management Network**: 10.1.0.0/24
  - Proxmox: 10.1.0.0
  - Raspberry Pi: 10.1.0.1 (pve2)
  - Jump Host: 10.1.0.100 (current deployment host)
- **Kubernetes Network**: 10.1.1.0/24
  - Master: k8s-master-01 (10.1.1.11)
  - Workers: k8s-worker-01 to k8s-worker-07 (10.1.1.21-27)
  - LoadBalancer Services: 10.1.1.100-150
- **Pod Network**: 10.244.0.0/16 (Flannel CNI)
- **Service Network**: 10.96.0.0/12

## 🚀 Quick Start

### Prerequisites

1. **Tools Required**:

   ```bash
   # Install required tools
   sudo apt update && sudo apt install -y \
     terraform ansible kubectl helm jq curl
   ```

2. **SSH Access**:

   ```bash
   # Generate SSH key if not exists
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/homelab_rsa -N ""

   # Copy to Proxmox and Pi
   ssh-copy-id -i ~/.ssh/homelab_rsa.pub root@10.1.0.0
   ssh-copy-id -i ~/.ssh/homelab_rsa.pub root@10.1.0.1
   ```

3. **Terraform Configuration**:
   ```bash
   cd terraform/environments/production
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your settings
   ```

### Deployment Options

#### Option 1: Full Automated Deployment

```bash
./deploy-homelab.sh
```

#### Option 2: Interactive Phase-by-Phase

```bash
./deploy-homelab.sh --interactive
```

#### Option 3: Manual Phase Execution

```bash
# Phase 1: Infrastructure
cd terraform/environments/production
terraform init && terraform apply

# Phase 2: Kubernetes
cd ../../../ansible
ansible-playbook -i inventories/terraform.ini playbooks/k8s/complete-deploy.yaml

# Phase 3: Services
kubectl apply -f ../deployment/k8s-manifests/

# Phase 4: Raspberry Pi
./deployment/setup-raspberry-pi.sh

# Phase 5: Testing
./deployment/test-deployment.sh
```

## 📋 Directory Structure

```
deployment/
├── README.md                    # This guide
├── deploy-homelab.sh           # Master deployment script
├── test-deployment.sh          # Comprehensive testing
├── setup-raspberry-pi.sh       # Pi configuration
├── k8s-manifests/             # Kubernetes resources
│   ├── plex.yaml              # Media server with GPU
│   ├── monitoring-configs.yaml # Prometheus/Grafana
│   └── storage-classes.yaml   # Longhorn storage
├── security/                  # Security policies
│   ├── network-policies.yaml  # Network segmentation
│   └── pod-security-standards.yaml # Pod security
└── backup/                    # Backup strategies
    └── backup-strategy.sh     # Automated backups
```

## 🔧 Configuration Files

### Terraform Infrastructure

- **Location**: `terraform/environments/production/`
- **Key Files**:
  - `k8s-cluster.tf` - VM definitions with tags
  - `infrastructure-vms.tf` - Support services
  - `variables.tf` - Configuration variables
  - `terraform.tfvars` - Your specific settings

### Ansible Automation

- **Location**: `ansible/`
- **Key Playbooks**:
  - `playbooks/k8s/complete-deploy.yaml` - Full K8s deployment
  - `roles/k8s-prerequisites/` - Node preparation
  - `roles/containerd/` - Container runtime
  - `roles/kubernetes-base/` - K8s components

### Kubernetes Manifests

- **GPU-enabled Plex** with hardware transcoding
- **Longhorn storage** with multiple classes
- **Monitoring stack** with custom dashboards
- **Network policies** for security

## 🏷️ VM Tagging Strategy

All VMs are tagged for easy management:

- **k8s,master,control-plane,etcd,production** - Master nodes
- **k8s,worker,production,storage** - Storage workers (first 3)
- **k8s,worker,production,compute** - Compute workers
- **haproxy,loadbalancer,k8s-api,production** - Load balancers
- **storage,nfs,minio,infrastructure** - Storage server
- **monitoring,prometheus,grafana,infrastructure** - Monitoring
- **database,postgresql,mysql,infrastructure** - Database server

## 🎯 Service URLs

After deployment, services are accessible at:

- **Grafana**: http://10.1.1.100:3000 (admin/admin123)
- **Plex**: http://10.1.1.102:32400
- **Pi-hole**: http://10.1.0.1:8080 (admin/admin123)
- **Heimdall Dashboard**: http://10.1.0.1:8082
- **Uptime Kuma**: http://10.1.0.1:3001

## 🔒 Security Features

### Network Security

- **Network Policies**: Namespace isolation
- **Pod Security Standards**: Restricted/baseline policies
- **RBAC**: Role-based access control
- **TLS**: All inter-component communication

### Backup Strategy

- **Automated backups** of all components
- **30-day retention** policy
- **Verification** of backup integrity
- **Remote sync** capability (optional)

## 🧪 Testing & Validation

The test suite validates:

- ✅ Kubernetes cluster health
- ✅ Storage provisioning
- ✅ Network connectivity
- ✅ Monitoring stack
- ✅ Service availability
- ✅ Resource usage
- ✅ Security policies

Run tests: `./test-deployment.sh`

## 🔄 Maintenance

### Daily Operations

```bash
# Check cluster status
kubectl get nodes
kubectl get pods -A

# Check service health
./check-pi-services.sh

# View resource usage
kubectl top nodes
kubectl top pods -A
```

### Backup Operations

```bash
# Manual backup
./backup/backup-strategy.sh

# Schedule automatic backups (add to crontab)
0 2 * * * /home/ubuntu/src/homelab/deployment/backup/backup-strategy.sh
```

### Updates

```bash
# Update Kubernetes components
ansible-playbook -i inventories/terraform.ini playbooks/k8s/upgrade.yaml

# Update Pi services
ssh root@10.1.0.1 'cd /opt/homelab-services && docker-compose pull && docker-compose up -d'
```

## 🆘 Troubleshooting

### Common Issues

**Pods stuck in Pending**:

```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl get events -n <namespace>
```

**Storage issues**:

```bash
kubectl get pv,pvc -A
kubectl get sc
kubectl logs -n longhorn-system <longhorn-pod>
```

**Network connectivity**:

```bash
kubectl get svc -A
kubectl get ingress -A
kubectl exec -it <pod> -- nslookup kubernetes.default
```

### Recovery Procedures

- **VM Recovery**: Use Proxmox snapshots and backups
- **K8s Recovery**: Restore from ETCD backup
- **Data Recovery**: Use Longhorn volume snapshots
- **Full Recovery**: Restore from backup strategy

## 📈 Scaling

### Adding Nodes

1. Update Terraform variables (worker_count)
2. Run `terraform apply`
3. Run Ansible playbook for new nodes
4. Label nodes appropriately

### Resource Optimization

- Monitor Grafana dashboards
- Adjust resource requests/limits
- Scale deployments based on usage
- Optimize storage allocation

## 🤝 Contributing

1. Test changes in a development environment
2. Update documentation for any changes
3. Run the test suite before committing
4. Follow the established patterns and conventions

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE.md) file for details.

---

🎉 **Congratulations!** You now have a production-grade HomeLab with enterprise features including high availability, monitoring, security, and automated backups.
