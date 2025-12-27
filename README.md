# Homelab

Production-ready Kubernetes cluster for self-hosting services.

## Cluster

- **15 nodes**: 3 HA masters + 10 AMD64 workers + 2 ARM64 workers
- **Platform**: Kubernetes v1.31.0, Flannel CNI, containerd
- **Load balancing**: MetalLB (L4) + Traefik (L7)
- **Monitoring**: Prometheus, Grafana, Loki

## Structure

```
homelab/
├── infra/              # Provisioning & configuration
│   ├── terraform/      # VM creation on Proxmox
│   ├── proxmox/        # Hypervisor templates
│   └── ansible/        # Cluster bootstrap
├── k8s/                # Kubernetes manifests
│   ├── system/         # Core (metallb, traefik, storage)
│   ├── monitoring/     # Prometheus, Grafana, Loki
│   └── apps/           # Applications
├── scripts/            # Automation
└── docs/               # Documentation
```

## Quick Start

```bash
# 1. Provision VMs
cd infra/terraform && terraform apply

# 2. Bootstrap cluster
cd ../ansible && ansible-playbook -i inventory.ini k8s-setup.yml

# 3. Deploy
kubectl apply -f k8s/system/
kubectl apply -f k8s/monitoring/
kubectl apply -f k8s/apps/
```

## Network

```
Internet → Mikrotik (10.0.0.1)
    ↓
HAProxy (10.1.1.50:6443)
    ↓
K8s Masters (10.1.1.11-13)
    ↓
Workers (10.1.1.31-40, 10.1.1.60-61)

MetalLB: 10.1.1.100-150
Pods: 10.244.0.0/16
```

## Docs

- [Architecture](docs/architecture.md)
- [Kubernetes](docs/k8s.md)
- [Traefik](docs/traefik-routing.md)
- [Services](docs/deployed-services.md)
