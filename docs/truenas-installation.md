# TrueNAS Installation Guide for VM 2032

## Prerequisites
- VM ID: 2032
- Recommended specs:
  - CPU: 4 cores
  - RAM: 8GB minimum (16GB recommended)
  - Boot disk: 32GB
  - Storage disks: Depends on your storage needs
  - Network: Bridge to homelab network (10.1.1.0/24)
  - IP: 10.1.1.201 (suggested)

## Installation Steps

### 1. Download TrueNAS SCALE ISO
```bash
# On Proxmox host
cd /var/lib/vz/template/iso
wget https://download.truenas.com/truenas-scale-dragonfish/TrueNAS-SCALE-24.10.0.iso
```

### 2. Create VM in Proxmox
```bash
# Via Proxmox Web UI:
# 1. Create New VM (ID: 2032)
# 2. General: Name = truenas
# 3. OS: Select TrueNAS ISO
# 4. System: UEFI, SCSI controller
# 5. Disks: 32GB boot disk, add additional storage disks
# 6. CPU: 4 cores
# 7. Memory: 8192MB (or 16384MB)
# 8. Network: Bridge vmbr0
```

### 3. Install TrueNAS
1. Boot from ISO
2. Select "Install/Upgrade"
3. Choose boot disk
4. Set admin password
5. Reboot after installation

### 4. Initial Configuration
1. Access Web UI at http://10.1.1.201 (or DHCP assigned IP)
2. Login with admin credentials
3. Configure static IP: 10.1.1.201
4. Set hostname: truenas.homelab.local

### 5. Configure Storage Pool
1. Storage → Pools → Add
2. Create ZFS pool with your storage disks
3. Name: "k8s-storage" or "main-pool"
4. Configure RAID level (mirror/raidz1/raidz2)

### 6. Create NFS Shares for Kubernetes
```
# Create datasets:
1. Storage → Pools → Add Dataset
   - Name: k8s-pvcs (for Kubernetes persistent volumes)
   - Name: immich-data (for Immich photos)
   - Name: media (for Plex/Jellyfin)
   - Name: backups (for Velero backups)

2. Sharing → Unix Shares (NFS) → Add
   - Path: /mnt/main-pool/k8s-pvcs
   - Enable: Yes
   - Maproot User: root
   - Maproot Group: root
   - Network: 10.1.1.0/24
```

### 7. Test NFS from Kubernetes
```bash
# From any K8s node
sudo apt-get install -y nfs-common
sudo mkdir -p /mnt/test-nfs
sudo mount -t nfs 10.1.1.201:/mnt/main-pool/k8s-pvcs /mnt/test-nfs
df -h | grep nfs
sudo umount /mnt/test-nfs
```

## Next Steps
- Install NFS CSI driver in Kubernetes
- Configure StorageClass for NFS
- Deploy applications using NFS storage
