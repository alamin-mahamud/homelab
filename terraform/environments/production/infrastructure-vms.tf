# Infrastructure VMs for HomeLab Services

# Storage Server (NFS/MinIO)
resource "proxmox_vm_qemu" "storage_server" {
  count = var.deploy_storage ? 1 : 0

  name        = "storage-server"
  vmid        = 1300
  target_node = var.proxmox_node
  clone       = var.vm_template_name
  full_clone  = true
  
  tags        = "storage,nfs,minio,infrastructure,production"
  desc        = "Central Storage Server - NFS and MinIO S3"

  agent    = 1
  os_type  = "cloud-init"
  cores    = 4
  sockets  = 1
  cpu      = "host"
  memory   = 8192
  scsihw   = "virtio-scsi-single"
  bootdisk = "scsi0"
  boot     = "order=scsi0"

  disks {
    scsi {
      scsi0 {
        disk {
          size    = "50G"
          storage = var.vm_storage
          iothread = true
          discard = true
        }
      }
      scsi1 {
        disk {
          size    = "500G"
          storage = var.vm_storage
          iothread = true
          discard = true
        }
      }
    }
  }

  network {
    model  = "virtio"
    bridge = var.network_bridge
    tag    = -1
  }

  ipconfig0 = "ip=${cidrhost(var.k8s_network_cidr, 5)}/24,gw=${var.network_gateway}"
  
  ciuser     = "ubuntu"
  sshkeys    = join("\n", var.ssh_public_keys)
  nameserver = join(" ", var.network_dns)
  searchdomain = var.network_domain

  lifecycle {
    ignore_changes = [
      ciuser,
      sshkeys,
      network
    ]
  }
}

# GitLab Server
resource "proxmox_vm_qemu" "gitlab" {
  name        = "gitlab-server"
  vmid        = 1310
  target_node = var.proxmox_node
  clone       = var.vm_template_name
  full_clone  = true
  
  tags        = "gitlab,git,ci-cd,infrastructure,production"
  desc        = "GitLab Server - Code Repository and CI/CD"

  agent    = 1
  os_type  = "cloud-init"
  cores    = 4
  sockets  = 1
  cpu      = "host"
  memory   = 8192
  scsihw   = "virtio-scsi-single"
  bootdisk = "scsi0"
  boot     = "order=scsi0"

  disks {
    scsi {
      scsi0 {
        disk {
          size    = "100G"
          storage = var.vm_storage
          iothread = true
          discard = true
        }
      }
    }
  }

  network {
    model  = "virtio"
    bridge = var.network_bridge
    tag    = -1
  }

  ipconfig0 = "ip=${cidrhost(var.k8s_network_cidr, 107)}/24,gw=${var.network_gateway}"
  
  ciuser     = "ubuntu"
  sshkeys    = join("\n", var.ssh_public_keys)
  nameserver = join(" ", var.network_dns)
  searchdomain = var.network_domain

  lifecycle {
    ignore_changes = [
      ciuser,
      sshkeys,
      network
    ]
  }
}

# Monitoring Server (Standalone Prometheus/Grafana)
resource "proxmox_vm_qemu" "monitoring" {
  name        = "monitoring-server"
  vmid        = 1320
  target_node = var.proxmox_node
  clone       = var.vm_template_name
  full_clone  = true
  
  tags        = "monitoring,prometheus,grafana,infrastructure,production"
  desc        = "Monitoring Server - Prometheus, Grafana, AlertManager"

  agent    = 1
  os_type  = "cloud-init"
  cores    = 4
  sockets  = 1
  cpu      = "host"
  memory   = 6144
  scsihw   = "virtio-scsi-single"
  bootdisk = "scsi0"
  boot     = "order=scsi0"

  disks {
    scsi {
      scsi0 {
        disk {
          size    = "100G"
          storage = var.vm_storage
          iothread = true
          discard = true
        }
      }
    }
  }

  network {
    model  = "virtio"
    bridge = var.network_bridge
    tag    = -1
  }

  ipconfig0 = "ip=${cidrhost(var.k8s_network_cidr, 100)}/24,gw=${var.network_gateway}"
  
  ciuser     = "ubuntu"
  sshkeys    = join("\n", var.ssh_public_keys)
  nameserver = join(" ", var.network_dns)
  searchdomain = var.network_domain

  lifecycle {
    ignore_changes = [
      ciuser,
      sshkeys,
      network
    ]
  }
}

# Database Server
resource "proxmox_vm_qemu" "database" {
  name        = "database-server"
  vmid        = 1330
  target_node = var.proxmox_node
  clone       = var.vm_template_name
  full_clone  = true
  
  tags        = "database,postgresql,mysql,infrastructure,production"
  desc        = "Database Server - PostgreSQL and MySQL"

  agent    = 1
  os_type  = "cloud-init"
  cores    = 4
  sockets  = 1
  cpu      = "host"
  memory   = 8192
  scsihw   = "virtio-scsi-single"
  bootdisk = "scsi0"
  boot     = "order=scsi0"

  disks {
    scsi {
      scsi0 {
        disk {
          size    = "50G"
          storage = var.vm_storage
          iothread = true
          discard = true
        }
      }
      scsi1 {
        disk {
          size    = "200G"
          storage = var.vm_storage
          iothread = true
          discard = true
        }
      }
    }
  }

  network {
    model  = "virtio"
    bridge = var.network_bridge
    tag    = -1
  }

  ipconfig0 = "ip=${cidrhost(var.k8s_network_cidr, 6)}/24,gw=${var.network_gateway}"
  
  ciuser     = "ubuntu"
  sshkeys    = join("\n", var.ssh_public_keys)
  nameserver = join(" ", var.network_dns)
  searchdomain = var.network_domain

  lifecycle {
    ignore_changes = [
      ciuser,
      sshkeys,
      network
    ]
  }
}

# Output infrastructure IPs
output "infrastructure_ips" {
  value = {
    storage    = var.deploy_storage ? cidrhost(var.k8s_network_cidr, 5) : null
    gitlab     = cidrhost(var.k8s_network_cidr, 107)
    monitoring = cidrhost(var.k8s_network_cidr, 100)
    database   = cidrhost(var.k8s_network_cidr, 6)
  }
}