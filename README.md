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
├── infrastructure/     # Base infrastructure provisioning
│   ├── terraform/      # VM creation on Proxmox
│   └── proxmox/        # Hypervisor templates
├── cluster/            # Kubernetes cluster bootstrap
│   └── ansible/        # Automation, roles, playbooks
├── platform/           # Platform services
│   ├── metallb/        # L4 load balancer
│   ├── traefik/        # L7 ingress controller
│   └── storage/        # Storage classes
├── apps/               # Application deployments
│   ├── home-assistant/
│   ├── immich/
│   ├── vaultwarden/
│   └── ...
├── observability/      # Monitoring & logging
│   ├── dashboards/
│   └── helm/
├── scripts/            # Automation scripts
└── docs/               # Documentation
```

## Quick Start

```bash
# 1. Provision infrastructure
cd infrastructure/terraform
terraform init && terraform apply

# 2. Bootstrap cluster
cd ../../cluster/ansible
ansible-playbook -i inventory.ini k8s-setup.yml

# 3. Deploy platform services
kubectl apply -f platform/metallb/
kubectl apply -f platform/traefik/

# 4. Deploy applications
kubectl apply -f apps/
```

## Network

```
Internet → Mikrotik (10.0.0.1)
    ↓
HAProxy LB (10.1.1.50:6443)
    ↓
K8s Masters (10.1.1.11-13)
    ↓
├─ AMD64 Workers (10.1.1.31-40)
└─ ARM64 Workers (10.1.1.60-61)

MetalLB Pool: 10.1.1.100-150
Pod Network: 10.244.0.0/16
```

## Documentation

- [Architecture](docs/architecture.md)
- [Kubernetes Setup](docs/k8s.md)
- [Traefik Routing](docs/traefik-routing.md)
- [Deployed Services](docs/deployed-services.md)
- [Quick Start](docs/quick-start.md)

## License

MIT
