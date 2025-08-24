# HomeLab Complete Deployment Plan

## Infrastructure Overview
- **Current Status**: Existing K8s cluster with 3 masters and multiple workers on Proxmox
- **Target**: Expand to 10+ node K8s cluster with comprehensive HomeLab services
- **Jump Host**: 10.7.0.1 (current execution node)
- **Proxmox Primary**: 10.1.0.0
- **Raspberry Pi**: 10.1.0.1 (lightweight services)

## Phase 1: Infrastructure Preparation (Day 1)

### 1.1 Backup Existing Infrastructure
```bash
# Backup current K8s cluster configs
kubectl get all -A -o yaml > k8s-backup-$(date +%Y%m%d).yaml
kubectl get pv,pvc -A -o yaml > storage-backup-$(date +%Y%m%d).yaml
kubectl get configmap,secret -A -o yaml > configs-backup-$(date +%Y%m%d).yaml

# Backup Proxmox VM configurations
ssh root@10.1.0.0 "vzdump --all --compress lzo --storage local --mode snapshot"

# Backup existing deployment configs
tar -czf homelab-backup-$(date +%Y%m%d).tar.gz /home/ubuntu/src/homelab/
```

### 1.2 Configure Jump Host (10.7.0.1)
```bash
# Install required tools
sudo apt-get update && sudo apt-get install -y \
  ansible ansible-lint \
  kubectl helm \
  git curl wget \
  python3-pip jq \
  sshpass rsync

# Setup kubectl
curl -LO "https://dl.k8s.io/release/v1.28.15/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Configure SSH keys for infrastructure access
ssh-keygen -t rsa -b 4096 -f ~/.ssh/homelab_rsa -N ""
ssh-copy-id -i ~/.ssh/homelab_rsa.pub root@10.1.0.0
ssh-copy-id -i ~/.ssh/homelab_rsa.pub pi@10.1.0.1
```

## Phase 2: Kubernetes Cluster Expansion (Day 1-2)

### 2.1 Create Additional K8s Nodes on Proxmox
```bash
# Deploy 4 additional worker nodes (total 10 nodes)
# Workers 8-11: 10.1.1.28 - 10.1.1.31
for i in {8..11}; do
  qm clone 999 10$((20+$i)) --name k8s-worker-0$i --full
  qm set 10$((20+$i)) --cores 4 --memory 8192 --net0 virtio,bridge=vmbr0
  qm set 10$((20+$i)) --ipconfig0 ip=10.1.1.$((20+$i))/24,gw=10.1.1.1
  qm start 10$((20+$i))
done
```

### 2.2 Ansible Inventory Configuration
```yaml
# /home/ubuntu/src/homelab/ansible/inventories/production.ini
[k8s_masters]
k8s-master-01 ansible_host=10.1.1.11
k8s-master-02 ansible_host=10.1.1.12
k8s-master-03 ansible_host=10.1.1.13

[k8s_workers]
k8s-worker-01 ansible_host=10.1.1.21
k8s-worker-02 ansible_host=10.1.1.22
k8s-worker-03 ansible_host=10.1.1.23
k8s-worker-04 ansible_host=10.1.1.24
k8s-worker-05 ansible_host=10.1.1.25
k8s-worker-06 ansible_host=10.1.1.26
k8s-worker-07 ansible_host=10.1.1.27
k8s-worker-08 ansible_host=10.1.1.28
k8s-worker-09 ansible_host=10.1.1.29
k8s-worker-10 ansible_host=10.1.1.30
k8s-worker-11 ansible_host=10.1.1.31

[raspberry_pi]
pi-node ansible_host=10.1.0.1 ansible_user=pi

[haproxy]
haproxy-lb ansible_host=10.1.1.10

[all:vars]
ansible_user=root
ansible_ssh_private_key_file=~/.ssh/homelab_rsa
```

### 2.3 Deploy K8s with Ansible
```bash
# Run comprehensive K8s deployment playbook
ansible-playbook -i inventories/production.ini playbooks/k8s/deploy.yaml

# Specific playbook tasks:
# - Install containerd runtime
# - Configure kernel modules and sysctl
# - Install kubeadm, kubelet, kubectl
# - Initialize first master with kubeadm
# - Join additional masters (HA control plane)
# - Join all worker nodes
# - Deploy Flannel CNI
# - Deploy metrics-server
```

## Phase 3: Storage & Networking (Day 2)

### 3.1 Deploy Longhorn Distributed Storage
```bash
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/longhorn.yaml
kubectl create -f k8s-manifests/storage-classes.yaml

# Configure storage nodes with labels
kubectl label nodes k8s-worker-01 k8s-worker-02 k8s-worker-03 storage=longhorn
```

### 3.2 Deploy MetalLB Load Balancer
```bash
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
EOF
```

### 3.3 Deploy NGINX Ingress Controller
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer
```

## Phase 4: Monitoring Stack (Day 2-3)

### 4.1 Deploy Prometheus & Grafana
```bash
# Deploy kube-prometheus-stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.retention=30d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=longhorn \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi
```

### 4.2 Configure GPU Monitoring (RTX 4080)
```bash
# Deploy NVIDIA GPU operator
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator --create-namespace

# Deploy dcgm-exporter for GPU metrics
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/dcgm-exporter/main/deployment/dcgm-exporter.yaml
```

## Phase 5: HomeLab Services Deployment (Day 3-4)

### 5.1 Core Services
```bash
# Deploy all homelab services
kubectl apply -f k8s-manifests/

# Services include:
# - Plex Media Server (with GPU transcoding)
# - Jellyfin (backup media server)
# - Home Assistant (smart home)
# - Nextcloud (personal cloud)
# - Pi-hole (DNS filtering)
# - Portainer (container management)
# - Heimdall (dashboard)
# - Vaultwarden (password manager)
# - GitLab (code repository)
# - Jenkins (CI/CD)
```

### 5.2 Service-Specific Configurations
```yaml
# Plex with GPU support
apiVersion: apps/v1
kind: Deployment
metadata:
  name: plex
  namespace: media
spec:
  template:
    spec:
      nodeSelector:
        nvidia.com/gpu: "true"
      containers:
      - name: plex
        resources:
          limits:
            nvidia.com/gpu: 1
```

## Phase 6: Raspberry Pi Configuration (Day 4)

### 6.1 Deploy Lightweight Services on Pi
```bash
# Ansible playbook for Pi configuration
ansible-playbook -i inventories/production.ini playbooks/raspberry-pi.yaml

# Services to deploy:
# - Pi-hole (primary DNS)
# - Mosquitto MQTT broker
# - Node-RED (automation)
# - InfluxDB (time-series data)
# - Telegraf (metrics collection)
```

### 6.2 Pi Integration with K8s
```bash
# Configure Pi as external service endpoint
kubectl create service externalname pihole-external \
  --external-name=10.1.0.1 \
  --namespace=network
```

## Phase 7: Security & Backup (Day 4-5)

### 7.1 Security Hardening
```bash
# Network policies
kubectl apply -f security/network-policies/

# RBAC configuration
kubectl apply -f security/rbac/

# Secrets management with Sealed Secrets
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.5/controller.yaml
```

### 7.2 Backup Strategy
```bash
# Deploy Velero for K8s backup
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm install velero vmware-tanzu/velero \
  --namespace velero --create-namespace \
  --set configuration.provider=aws \
  --set configuration.backupStorageLocation.bucket=homelab-backups \
  --set configuration.backupStorageLocation.config.region=minio \
  --set configuration.backupStorageLocation.config.s3ForcePathStyle=true \
  --set configuration.backupStorageLocation.config.s3Url=http://minio.storage:9000
```

## Phase 8: Testing & Validation (Day 5)

### 8.1 Infrastructure Tests
```bash
# Test script location: deployment/test-deployment.sh
./test-deployment.sh

# Tests include:
# - All nodes responding
# - All pods running
# - Storage provisioning
# - Load balancer functionality
# - Service accessibility
# - DNS resolution
# - GPU metrics collection
```

### 8.2 Service Health Checks
```bash
# Automated health check script
for service in plex jellyfin nextcloud home-assistant pihole; do
  kubectl exec -n monitoring deploy/prometheus -- \
    promtool query instant "up{job=\"$service\"}"
done
```

## Phase 9: Documentation & Handover

### 9.1 Access URLs
| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://10.1.1.100:3000 | admin/admin123 |
| Prometheus | http://10.1.1.101:9090 | - |
| Plex | http://10.1.1.102:32400 | Configure on first login |
| Nextcloud | http://10.1.1.103 | admin/admin123 |
| Home Assistant | http://10.1.1.104:8123 | Configure on first login |
| Pi-hole | http://10.1.1.105/admin | admin/admin123 |
| Portainer | http://10.1.1.106:9000 | Configure on first login |
| GitLab | http://10.1.1.107 | root/admin123 |

### 9.2 Maintenance Commands
```bash
# View cluster status
kubectl get nodes
kubectl get pods -A

# View service endpoints
kubectl get svc -A

# Check storage
kubectl get pv,pvc -A

# Monitor resource usage
kubectl top nodes
kubectl top pods -A

# View logs
kubectl logs -n <namespace> <pod-name>

# Scale deployments
kubectl scale deployment/<name> --replicas=3 -n <namespace>
```

## Execution Commands Summary

To execute this plan, run these commands in sequence:

```bash
# Phase 1: Preparation
cd /home/ubuntu/src/homelab/deployment
./prepare-infrastructure.sh

# Phase 2: K8s Cluster
./deploy-k8s-cluster.sh

# Phase 3: Storage & Networking  
./deploy-storage-network.sh

# Phase 4: Monitoring
./deploy-monitoring-stack.sh

# Phase 5: HomeLab Services
./deploy-homelab-services.sh

# Phase 6: Raspberry Pi
./setup-raspberry-pi.sh

# Phase 7: Security & Backup
./configure-security-backup.sh

# Phase 8: Testing
./test-deployment.sh

# Or run everything:
./deploy-complete-homelab.sh
```

## Rollback Plan

If issues occur:
```bash
# Restore from backup
kubectl apply -f k8s-backup-YYYYMMDD.yaml

# Remove problematic deployments
kubectl delete deployment <name> -n <namespace>

# Restore Proxmox VMs
ssh root@10.1.0.0 "qmrestore <backup-file> <vmid>"
```

## Success Criteria

- [ ] All 10+ K8s nodes online and ready
- [ ] Storage provisioning working
- [ ] Load balancer assigning IPs
- [ ] All services accessible via URLs
- [ ] Monitoring showing all metrics
- [ ] GPU metrics visible in Grafana
- [ ] Raspberry Pi services integrated
- [ ] Backup system operational
- [ ] DNS filtering active
- [ ] All health checks passing

---
Generated: $(date)
Repository: github.com/alamin-mahamud/homelab