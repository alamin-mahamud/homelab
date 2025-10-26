# Infrastructure TODO

## Immediate Tasks
- [ ] Initialize and deploy main infrastructure on pve1
- [ ] Create Ansible playbooks for Kubernetes deployment
- [ ] Test and validate cluster deployment

## Future Enhancements

### pve2 (Raspberry Pi) Node Integration
- [ ] **Add pve2 node support** (10.1.0.1 - Raspberry Pi)
- [ ] **Lightweight worker nodes** for edge computing
- [ ] **Service distribution**:
  - DNS services (Pi-hole)
  - IoT services (MQTT, Zigbee2MQTT)
  - Edge monitoring (Node Exporter)
  - Lightweight applications
- [ ] **Terraform multi-node** support
- [ ] **ARM64 workload scheduling** 
- [ ] **Network optimization** for Pi limitations

### Architecture Goals
```
Target Distribution:
├── pve1 (x86_64): Core K8s cluster (masters + main workers)
├── pve2 (ARM64):  Edge services + lightweight workers
└── Hybrid workloads across both nodes
```

### Implementation Notes
- Use node selectors for architecture-specific workloads
- Separate storage classes for different performance tiers
- Network policies for traffic segmentation
- Resource limits appropriate for Pi hardware

## Applications Pipeline
- [ ] Storage: TrueNAS + Longhorn
- [ ] Monitoring: Prometheus + Grafana
- [ ] Media: Immich (photo management)
- [ ] Backup: Proxmox Backup Server integration
- [ ] Networking: Advanced ingress with SSL termination