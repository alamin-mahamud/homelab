# Homelab Self-Hosting Platform

Production-ready Kubernetes cluster for self-hosting services with high availability, multi-architecture support, and full observability.

## Overview

A 15-node Kubernetes cluster running on Proxmox, designed for hosting homelab services with enterprise-grade reliability.

**Infrastructure:** 3 HA masters + 10 AMD64 workers + 2 ARM64 workers
**Platform:** Kubernetes v1.31.0 with Flannel CNI
**Monitoring:** Full observability stack (Prometheus, Grafana, Loki)
**Load Balancing:** MetalLB (L4) + Traefik (L7) for service exposure

## Quick Start

```bash
# Access cluster
export KUBECONFIG=~/.kube/config
kubectl get nodes

# Deploy a service
kubectl apply -f your-app.yaml

# View monitoring
open http://10.1.1.31:30000  # Grafana
```

## Network Architecture

```
Internet → Mikrotik (10.0.0.1)
    ↓
HAProxy LB (10.1.1.50:6443)
    ↓
K8s Masters (10.1.1.11-13) [HA Control Plane]
    ↓
├─ AMD64 Workers (10.1.1.31-40)
└─ ARM64 Workers (10.1.1.60-61)

MetalLB Pool: 10.1.1.100-150
Pod Network: 10.244.0.0/16
Service Network: 10.96.0.0/12
```

## Core Services

| Service | Purpose | Access |
|---------|---------|--------|
| **Grafana** | Monitoring dashboard | http://10.1.1.31:30000 |
| **Prometheus** | Metrics collection | Internal |
| **Loki** | Log aggregation | Internal |
| **MetalLB** | L4 load balancer | 10.1.1.100-150 |
| **Traefik** | Ingress controller | Ready to deploy |

## Infrastructure

- **Hypervisor:** Proxmox VE on AMD Ryzen 9 + Raspberry Pi 5
- **OS:** Ubuntu 22.04 LTS (AMD64), Ubuntu 24.04 (ARM64)
- **Container Runtime:** containerd v1.7.28
- **CNI:** Flannel for pod networking
- **Storage:** Local storage + ready for distributed storage (Longhorn)

## Key Features

✅ **High Availability** - 3-node control plane with automatic failover
✅ **Multi-Architecture** - Run both x86 and ARM workloads
✅ **Production Monitoring** - Full observability with Grafana stack
✅ **Load Balancing** - Layer 4 (MetalLB) + Layer 7 (Traefik) ready
✅ **Infrastructure as Code** - Terraform + Ansible automation
✅ **Hybrid Cloud Ready** - Multi-architecture support for edge deployments

## Deployment

```bash
# Infrastructure provisioning
cd terraform
terraform init && terraform apply

# Cluster setup
cd ../ansible
ansible-playbook -i inventory.ini k8s-setup.yml

# Deploy monitoring
kubectl apply -f monitoring/
```

## Documentation

- **[Architecture](docs/architecture.md)** - System design and components
- **[Load Balancing](docs/load-balancing-architecture.md)** - L4/L7 traffic routing
- **[Kubernetes Setup](docs/k8s.md)** - Cluster configuration
- **[Networking](docs/networking.md)** - Network design and VLANs
- **[Quick Start](docs/quick-start.md)** - Fast deployment guide

## Repository Structure

```
homelab/
├── ansible/           # K8s cluster automation
├── terraform/         # VM infrastructure provisioning
├── monitoring/        # Observability stack (Prometheus, Grafana, Loki)
├── docs/             # Comprehensive documentation
└── WORK_LOG.md       # Current session activity
```

## Common Operations

```bash
# Cluster health
kubectl get nodes -o wide
kubectl get pods -A

# Monitoring
kubectl get pods -n monitoring
kubectl logs -f -n monitoring <pod-name>

# Load balancer
kubectl get svc -n metallb-system
kubectl get ipaddresspool -n metallb-system

# Interactive management
k9s
```

## Service Deployment Example

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  annotations:
    metallb.universe.tf/allow-shared-ip: "shared"
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: my-app
```

## Next Steps for Self-Hosting

1. **Deploy ingress rules** - Route traffic to your services
2. **Add DNS records** - Point domains to MetalLB IPs
3. **Enable TLS** - Use cert-manager for automatic HTTPS
4. **Deploy apps** - Home Assistant, Nextcloud, Plex, etc.
5. **Configure backups** - Set up Velero or similar

## License

MIT
