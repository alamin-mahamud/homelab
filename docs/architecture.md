# Architecture Overview

Production-grade, highly available Kubernetes platform for self-hosting services, built on Proxmox virtualization with full automation.

## System Architecture

```
Internet/Mikrotik (10.0.0.1)
    ↓
HAProxy LB (10.1.1.50:6443)
    ↓
┌─────────────────────────────────────────┐
│     Kubernetes Control Plane (HA)       │
│  Masters: 10.1.1.11, .12, .13           │
│  - API Server (port 6443)               │
│  - etcd (stacked, 3-node cluster)       │
│  - Scheduler & Controller Manager       │
└─────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────┐
│         Worker Nodes (15 total)         │
│  AMD64: 10.1.1.31-40 (10 nodes)         │
│  ARM64: 10.1.1.60-61 (2 nodes, RPi5)    │
└─────────────────────────────────────────┘
```

## Network Architecture

| VLAN/Network | Range | Purpose |
|--------------|-------|---------|
| **Management** | 10.0.0.0/24 | Proxmox, router, infrastructure |
| **Kubernetes** | 10.1.1.0/24 | K8s nodes, HAProxy |
| **Pod Network** | 10.244.0.0/16 | Flannel CNI pod networking |
| **Service Network** | 10.96.0.0/12 | ClusterIP services |
| **MetalLB Pool** | 10.1.1.100-150 | External LoadBalancer IPs |

### IP Allocations

```
10.0.0.1        Mikrotik Router (gateway)
10.1.1.50       HAProxy (K8s API load balancer)
10.1.1.11-13    K8s Master Nodes
10.1.1.31-40    K8s Worker Nodes (AMD64)
10.1.1.60-61    K8s Worker Nodes (ARM64, Raspberry Pi 5)
10.1.1.100-150  MetalLB IP Pool (LoadBalancer services)
```

## Technology Stack

### Infrastructure
- **Hypervisor:** Proxmox VE 8.x
- **OS:** Ubuntu 22.04 LTS (AMD64), Ubuntu 24.04 (ARM64)
- **Automation:** Terraform (infrastructure), Ansible (configuration)

### Kubernetes Platform
- **Version:** v1.31.0
- **Container Runtime:** containerd v1.7.28
- **CNI:** Flannel (pod networking)
- **Service Mesh:** None (optional: Istio)

### Load Balancing
- **Layer 4:** MetalLB (bare-metal load balancer)
- **Layer 7:** Traefik (ingress controller, ready to deploy)
- **API LB:** HAProxy (control plane access)

### Observability
- **Metrics:** Prometheus
- **Visualization:** Grafana (http://10.1.1.31:30000)
- **Logging:** Loki + Promtail
- **Alerting:** Alertmanager

### Storage
- **Current:** Local storage on nodes
- **Planned:** Longhorn (distributed block storage)
- **Backup:** Velero (cluster backup, to be configured)

## Resource Allocation

### Physical Hardware
```
AMD Ryzen 9 Server
├── CPU: 32 cores
├── RAM: 128GB DDR5
├── Storage: 2TB NVMe SSD
└── Network: Gigabit Ethernet

Raspberry Pi 5 (x2)
├── CPU: Quad-core ARM Cortex-A76
├── RAM: 8GB per node
└── Storage: 64GB SD card per node
```

### VM Allocation
```
HAProxy LB: 2 CPU, 2GB RAM, 20GB disk
Masters (x3): 4 CPU, 8GB RAM, 100GB disk each
Workers (x12): 4 CPU, 8-16GB RAM, 100-200GB disk each

Total: ~50 vCPU, ~90GB RAM allocated
```

## High Availability Design

### Control Plane HA
- **etcd:** 3-node cluster, stacked on master nodes
- **API Server:** 3 instances, load-balanced via HAProxy
- **Scheduler/Controller:** Active-passive with leader election

### Application HA
- **Pod Replication:** Multiple replicas across nodes
- **Node Affinity:** Spread workloads for resilience
- **Ingress:** Multiple Traefik replicas (when deployed)
- **Load Balancer:** MetalLB with IP failover

## Security Architecture

### Network Security
- **Firewall:** iptables/nftables on all nodes
- **Network Policies:** Calico network policies (optional)
- **TLS:** cert-manager for automatic certificates (to be configured)

### Authentication & Authorization
- **Infrastructure:** SSH key-based authentication
- **Kubernetes:** RBAC with service accounts
- **API Access:** Certificate-based authentication

## Deployment Architecture

### Infrastructure as Code
```
Git Repository
    ↓
Terraform → Provision VMs on Proxmox
    ↓
Ansible → Configure OS and deploy K8s
    ↓
kubectl/Helm → Deploy applications
    ↓
Running Cluster
```

### Automation Tools
- **Terraform:** VM provisioning and network configuration
- **Ansible:** OS configuration, K8s cluster setup
- **Helm/kubectl:** Application deployment
- **GitOps:** ArgoCD (optional, for continuous delivery)

## Current Status

✅ **Infrastructure:** 15 nodes operational
✅ **Control Plane:** 3-node HA setup running
✅ **Workers:** All 12 workers healthy
✅ **Networking:** Flannel CNI operational
✅ **Monitoring:** Prometheus, Grafana, Loki deployed
✅ **Load Balancing:** MetalLB operational (10.1.1.100-150)
⏳ **Ingress:** Traefik ready to deploy
⏳ **Storage:** Longhorn planned
⏳ **Backups:** Velero to be configured

## Future Enhancements

### Phase 2: Enhanced Platform
- **Service Mesh:** Istio for advanced traffic management
- **GitOps:** ArgoCD for declarative deployments
- **Security:** Falco runtime security, OPA policies
- **Certificates:** cert-manager with Let's Encrypt

### Phase 3: Storage & Backup
- **Distributed Storage:** Longhorn with 3-replica setup
- **Backup Solution:** Velero with S3-compatible storage
- **Disaster Recovery:** Documented restore procedures

### Phase 4: Applications
- **Home Assistant:** Smart home automation
- **Nextcloud:** File sync and share
- **Plex/Jellyfin:** Media server
- **Pi-hole:** Network-wide ad blocking
- **Portainer:** Container management UI

---
*Last updated: 2025-10-26*
