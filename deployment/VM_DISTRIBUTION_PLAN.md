# VM Distribution Strategy Across Proxmox Nodes

## Current Issue
All VMs are currently deployed on the x86 node (`pve`). No VMs are running on the Raspberry Pi node.

## Updated Configuration

### Node Distribution Strategy
The Terraform configuration has been updated to distribute VMs across both nodes based on performance requirements:

#### **x86 Node (pve) - High Performance**
- **K8s Masters**: All 3 master nodes for control plane performance
- **K8s Workers**: First 3 workers (storage nodes) for Longhorn performance
- **Storage Server**: NFS/MinIO server for high I/O performance  
- **GitLab Server**: Code repository and CI/CD for compute performance
- **Database Server**: PostgreSQL/MySQL for transaction performance

#### **Raspberry Pi Node (rpi-node) - Lightweight Services**  
- **K8s Workers**: Remaining 8 workers (compute nodes) with reduced resources:
  - 2 CPU cores (vs 4 on x86)
  - 4GB RAM (vs 16GB on x86) 
  - 50GB disk (vs 200GB on x86)
- **Monitoring Server**: Prometheus/Grafana with reduced resources:
  - 2 CPU cores (vs 4)
  - 4GB RAM (vs 6GB)
  - 50GB disk (vs 100GB)

## Resource Allocation

### Masters (x86 only)
```hcl
k8s-master-01 -> pve      (4 cores, 8GB RAM, 100GB)
k8s-master-02 -> pve      (4 cores, 8GB RAM, 100GB) 
k8s-master-03 -> pve      (4 cores, 8GB RAM, 100GB)
```

### Workers (distributed)
```hcl
# Storage workers (x86 for performance)
k8s-worker-01 -> pve      (4 cores, 16GB RAM, 200GB)
k8s-worker-02 -> pve      (4 cores, 16GB RAM, 200GB)
k8s-worker-03 -> pve      (4 cores, 16GB RAM, 200GB)

# Compute workers (Raspberry Pi)
k8s-worker-04 -> rpi-node (2 cores, 4GB RAM, 50GB)
k8s-worker-05 -> rpi-node (2 cores, 4GB RAM, 50GB)
k8s-worker-06 -> rpi-node (2 cores, 4GB RAM, 50GB)
k8s-worker-07 -> rpi-node (2 cores, 4GB RAM, 50GB)
k8s-worker-08 -> rpi-node (2 cores, 4GB RAM, 50GB)
k8s-worker-09 -> rpi-node (2 cores, 4GB RAM, 50GB)
k8s-worker-10 -> rpi-node (2 cores, 4GB RAM, 50GB)
k8s-worker-11 -> rpi-node (2 cores, 4GB RAM, 50GB)
```

### Infrastructure Services
```hcl
storage-server     -> pve      (4 cores, 8GB RAM, 50GB + 500GB)
gitlab-server      -> pve      (4 cores, 8GB RAM, 100GB)
monitoring-server  -> rpi-node (2 cores, 4GB RAM, 50GB)
database-server    -> pve      (4 cores, 8GB RAM, 50GB + 200GB)
```

### Load Balancers
```hcl
haproxy-01 -> pve      (2 cores, 2GB RAM, 32GB)
haproxy-02 -> rpi-node (2 cores, 2GB RAM, 32GB)
```

## Required Steps

### 1. Verify Raspberry Pi Node Name
```bash
# From Proxmox web UI or CLI, check the actual node name
pvesh get /nodes
# or check from Proxmox web interface: Datacenter > Nodes
```

### 2. Update Node Name in Configuration
If your Raspberry Pi node has a different name, update:
```hcl
# In terraform.tfvars
proxmox_nodes = ["pve", "your-actual-rpi-node-name"]
```

### 3. Apply Changes
```bash
cd /home/ubuntu/src/homelab/terraform/environments/production
terraform plan   # Review changes
terraform apply  # Apply distribution
```

## Benefits of This Distribution

### Performance Optimization
- **Storage-intensive** services on x86 with faster disks
- **Compute-intensive** services on x86 with more CPU/RAM  
- **Lightweight** services on Raspberry Pi for cost efficiency

### High Availability
- Master nodes distributed for control plane HA
- Load balancers distributed across both nodes
- Services can tolerate single node failure

### Resource Efficiency  
- Raspberry Pi nodes handle lighter workloads
- x86 node focuses on performance-critical services
- Optimal resource utilization across hardware

## Current Status
✅ Configuration updated with node distribution strategy  
⏳ **Action Required**: Verify Raspberry Pi node name and apply changes  
⏳ **Next**: Apply terraform changes to redistribute VMs