# Homelab Documentation

Documentation for the self-hosting Kubernetes platform running on Proxmox.

## Quick Links

| Document | Purpose |
|----------|---------|
| **[Architecture](./architecture.md)** | System design, network topology, and technology stack |
| **[Load Balancing](./load-balancing-architecture.md)** | Layer 4 (MetalLB) and Layer 7 (Traefik) configuration |
| **[Kubernetes Setup](./k8s.md)** | Cluster deployment and configuration |
| **[Networking](./networking.md)** | Network design, VLANs, and routing |
| **[Quick Start](./quick-start.md)** | Fast deployment guide |

## Core Documentation

### Infrastructure
- **Architecture** - 15-node K8s cluster (3 masters, 12 workers) on Proxmox
- **Networking** - 10.1.1.0/24 with separate VLANs for management/storage
- **Hardware** - AMD Ryzen 9 server + Raspberry Pi 5 nodes

### Platform
- **Kubernetes** - v1.31.0 with Flannel CNI and containerd
- **Load Balancing** - MetalLB for L4, Traefik for L7 ingress
- **Monitoring** - Prometheus, Grafana, Loki stack
- **Storage** - Local storage, ready for Longhorn distributed storage

### Operations
- **IaC** - Terraform for VMs, Ansible for configuration
- **Monitoring** - Full observability with custom dashboards
- **Access** - k9s, stern, kubectl for cluster management

## Status

✅ **Cluster** - 15 nodes fully operational
✅ **Monitoring** - Grafana, Prometheus, Loki deployed
✅ **Load Balancing** - MetalLB operational (10.1.1.100-150)
⏳ **Ingress** - Traefik ready to deploy

## Getting Started

1. Review the [Architecture](./architecture.md) to understand the system design
2. Check [Kubernetes Setup](./k8s.md) for cluster details
3. Read [Load Balancing](./load-balancing-architecture.md) for traffic routing
4. Use [Quick Start](./quick-start.md) for deployment procedures

## Service Deployment

To deploy services on this homelab:

1. **Create deployment** - Standard K8s manifests or Helm charts
2. **Expose service** - Use LoadBalancer type for external access
3. **Configure ingress** - Add Traefik IngressRoute for HTTP/HTTPS
4. **Monitor** - View metrics in Grafana dashboard

See individual documentation files for detailed instructions.

---
*Last updated: 2025-10-26*