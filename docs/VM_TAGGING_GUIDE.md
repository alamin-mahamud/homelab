# VM Tagging Best Practices Guide

## 🏷️ **Why VM Tags Matter in Production**

VM tags in Proxmox provide critical organizational and operational benefits:

### **1. Infrastructure Management**
- **Quick identification** of VM roles and purposes
- **Batch operations** on VMs with specific tags
- **Resource planning** and capacity management
- **Documentation** that stays with the VM

### **2. Automation & Monitoring**
- **Ansible targeting** with tag-based inventories
- **Monitoring alerts** grouped by service type
- **Backup policies** based on criticality tags
- **Automated scaling** decisions

### **3. Operations & Troubleshooting**
- **Incident response** - quickly identify affected services
- **Maintenance windows** - group VMs by impact level
- **Compliance auditing** - track production vs development
- **Cost allocation** - charge-back by department/project

## 📋 **Our Production Tag Schema**

### **Tag Categories & Hierarchy**

#### **1. Service Layer Tags**
```
kubernetes          # K8s cluster member
etcd               # Database cluster member  
infrastructure     # Support services
```

#### **2. Role Tags**
```
control-plane      # K8s API server
master            # K8s master node
worker            # K8s worker node
database          # Data persistence
load-balancer     # Traffic distribution
storage           # Data storage
backup            # Backup services
```

#### **3. Architecture Tags**
```
ha                # High availability component
cluster           # Multi-node service
persistent        # Stateful service
compute           # Compute workloads
networking        # Network services
```

#### **4. Environment Tags**
```
production        # Production environment
staging           # Staging environment
development       # Development environment
testing           # Testing environment
```

#### **5. Operational Tags**
```
critical          # Business critical
storage-capable   # Can host storage
node-01           # Instance identifier
etcd-external     # External etcd (not embedded)
```

#### **6. Technology Tags**
```
haproxy           # HAProxy load balancer
truenas           # TrueNAS storage
kubernetes-api    # K8s API endpoint
proxmox-backup-server  # PBS backup
nfs               # NFS protocol support
smb               # SMB/CIFS protocol support
```

## 🎯 **Tag Usage Examples**

### **Bulk Operations**
```bash
# Start all K8s workers
for vm in $(qm list | grep "worker" | awk '{print $1}'); do qm start $vm; done

# Backup all critical infrastructure
for vm in $(pvesh get /cluster/resources --type vm --output-format json | jq -r '.[] | select(.tags | contains("critical")) | .vmid'); do
    vzdump $vm --storage backup-storage
done

# Update all production VMs
ansible-playbook update.yml --limit "tag_production"
```

### **Monitoring Groups**
```yaml
# Prometheus scrape configs
- job_name: 'k8s-masters'
  proxmox_sd_configs:
    - server: 'proxmox.local'
      tags: ['kubernetes', 'control-plane']

- job_name: 'etcd-cluster'  
  proxmox_sd_configs:
    - server: 'proxmox.local'
      tags: ['etcd', 'database']
```

### **Backup Policies**
```bash
# Critical systems - daily backups
tag:critical -> backup_schedule: "0 2 * * *"

# Production systems - weekly backups  
tag:production -> backup_schedule: "0 2 * * 0"

# Development - monthly backups
tag:development -> backup_schedule: "0 2 1 * *"
```

## 🔧 **Tag Management Commands**

### **View VM Tags**
```bash
# List all VMs with tags
qm list --output-format json | jq -r '.[] | "\(.vmid): \(.name) - \(.tags)"'

# Find VMs by tag
pvesh get /cluster/resources --type vm | grep "kubernetes"

# Get specific VM tags
qm config 2001 | grep "^tags:"
```

### **Modify Tags**
```bash
# Add tags
qm set 2001 --tags "kubernetes;master;production;ha"

# Remove specific tag
current_tags=$(qm config 2001 | grep "^tags:" | cut -d' ' -f2-)
new_tags=$(echo $current_tags | sed 's/old-tag;//g')
qm set 2001 --tags "$new_tags"
```

### **Tag-based Searches**
```bash
# Find all production VMs
pvesh get /cluster/resources --type vm --output-format json | 
  jq -r '.[] | select(.tags | contains("production")) | .name'

# Find HA components
pvesh get /cluster/resources --type vm --output-format json |
  jq -r '.[] | select(.tags | contains("ha")) | "\(.name) (\(.vmid))"'
```

## 📊 **Our Current Tag Distribution**

### **By Service Type**
- **Kubernetes**: 13 VMs (3 masters + 10 workers)
- **etcd**: 3 VMs (dedicated cluster)
- **Infrastructure**: 3 VMs (LB + storage + backup)

### **By Criticality**
- **Critical**: 2 VMs (TrueNAS + Proxmox Backup)
- **HA Components**: 6 VMs (3 masters + 3 etcd)
- **Production**: 19 VMs (all)

### **By Node Identification**
- **Numbered nodes**: node-01 through node-10
- **Role-specific**: master, worker, etcd cluster members

## 💡 **Pro Tips**

1. **Keep tags consistent** - Use lowercase, hyphens for multi-word
2. **Be descriptive** - Tags should be self-explanatory
3. **Use hierarchies** - General → Specific (kubernetes → master → node-01)
4. **Plan for automation** - Tags should enable scripts and monitoring
5. **Document changes** - Track tag schema evolution
6. **Regular audits** - Ensure tags stay current with VM purposes

## 🔮 **Future Enhancements**

- **Automatic tagging** via Terraform/Ansible
- **Tag-based RBAC** for team access control
- **Tag inheritance** for cloned VMs
- **Integration** with monitoring and alerting systems
- **Cost tracking** by tag-based resource usage