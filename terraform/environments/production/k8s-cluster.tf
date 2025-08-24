# K8s Cluster Configuration with proper tagging

locals {
  k8s_masters = {
    for i in range(var.master_count) : 
    "k8s-master-${format("%02d", i + 1)}" => {
      vmid        = 1100 + i
      ip_address  = cidrhost(var.k8s_network_cidr, 11 + i)
      cores       = var.master_cores
      memory      = var.master_memory
      disk_size   = var.master_disk_size
      tags        = "k8s,master,control-plane,etcd,production"
      description = "Kubernetes Master Node ${i + 1}"
    }
  }
  
  k8s_workers = {
    for i in range(var.worker_count) : 
    "k8s-worker-${format("%02d", i + 1)}" => {
      vmid        = 1200 + i
      ip_address  = cidrhost(var.k8s_network_cidr, 21 + i)
      cores       = var.worker_cores
      memory      = var.worker_memory
      disk_size   = var.worker_disk_size
      tags        = "k8s,worker,production,${i < 3 ? "storage" : "compute"}"
      description = "Kubernetes Worker Node ${i + 1}"
    }
  }

  all_k8s_nodes = merge(local.k8s_masters, local.k8s_workers)
}

# K8s Master Nodes
resource "proxmox_vm_qemu" "k8s_masters" {
  for_each = local.k8s_masters

  name        = each.key
  vmid        = each.value.vmid
  target_node = var.proxmox_node
  clone       = var.vm_template_name
  full_clone  = true
  
  tags        = each.value.tags
  desc        = each.value.description

  agent    = 1
  os_type  = "cloud-init"
  cores    = each.value.cores
  sockets  = 1
  cpu      = "host"
  memory   = each.value.memory
  scsihw   = "virtio-scsi-single"
  bootdisk = "scsi0"
  boot     = "order=scsi0"

  disks {
    scsi {
      scsi0 {
        disk {
          size    = each.value.disk_size
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

  ipconfig0 = "ip=${each.value.ip_address}/24,gw=${var.network_gateway}"
  
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

# K8s Worker Nodes
resource "proxmox_vm_qemu" "k8s_workers" {
  for_each = local.k8s_workers

  name        = each.key
  vmid        = each.value.vmid
  target_node = var.proxmox_node
  clone       = var.vm_template_name
  full_clone  = true
  
  tags        = each.value.tags
  desc        = each.value.description

  agent    = 1
  os_type  = "cloud-init"
  cores    = each.value.cores
  sockets  = 1
  cpu      = "host"
  memory   = each.value.memory
  scsihw   = "virtio-scsi-single"
  bootdisk = "scsi0"
  boot     = "order=scsi0"

  disks {
    scsi {
      scsi0 {
        disk {
          size    = each.value.disk_size
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

  ipconfig0 = "ip=${each.value.ip_address}/24,gw=${var.network_gateway}"
  
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

# HAProxy Load Balancers for K8s API
resource "proxmox_vm_qemu" "haproxy" {
  count = 2

  name        = "haproxy-${format("%02d", count.index + 1)}"
  vmid        = 1050 + count.index
  target_node = var.proxmox_node
  clone       = var.vm_template_name
  full_clone  = true
  
  tags        = "haproxy,loadbalancer,k8s-api,production,ha"
  desc        = "HAProxy Load Balancer ${count.index + 1} for K8s API"

  agent    = 1
  os_type  = "cloud-init"
  cores    = 2
  sockets  = 1
  cpu      = "host"
  memory   = 2048
  scsihw   = "virtio-scsi-single"
  bootdisk = "scsi0"
  boot     = "order=scsi0"

  disks {
    scsi {
      scsi0 {
        disk {
          size    = "32G"
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

  ipconfig0 = "ip=${cidrhost(var.k8s_network_cidr, 10 + count.index)}/24,gw=${var.network_gateway}"
  
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

# Output values for Ansible inventory
output "k8s_masters" {
  value = {
    for name, config in local.k8s_masters : name => {
      ip = config.ip_address
      vmid = config.vmid
    }
  }
}

output "k8s_workers" {
  value = {
    for name, config in local.k8s_workers : name => {
      ip = config.ip_address
      vmid = config.vmid
    }
  }
}

output "haproxy_ips" {
  value = [for i in range(2) : cidrhost(var.k8s_network_cidr, 10 + i)]
}