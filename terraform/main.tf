# Production-ready Kubernetes Infrastructure

terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.45.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  username  = var.proxmox_user
  password  = var.proxmox_password
  insecure  = true
}

# VM template is referenced directly by ID (999)

locals {
  # Calculate IP addresses using proper IP ranges
  master_ips = {
    for i, name in keys(var.k8s_masters) : name => cidrhost(var.network_cidr, var.ip_ranges.masters + index(keys(var.k8s_masters), name))
  }
  
  etcd_ips = {
    for i, name in keys(var.etcd_nodes) : name => cidrhost(var.network_cidr, var.ip_ranges.etcd + index(keys(var.etcd_nodes), name))
  }
  
  worker_ips = {
    for i, name in keys(var.k8s_workers) : name => cidrhost(var.network_cidr, var.ip_ranges.workers + index(keys(var.k8s_workers), name))
  }
  
  infrastructure_ips = {
    for i, name in keys(var.infrastructure_services) : name => cidrhost(var.network_cidr, var.ip_ranges.infrastructure + index(keys(var.infrastructure_services), name))
  }
  
  worker_pi_ips = {
    for i, name in keys(var.k8s_workers_pi) : name => cidrhost(var.network_cidr, var.ip_ranges.workers_pi + index(keys(var.k8s_workers_pi), name))
  }
}

# Kubernetes Master Nodes
resource "proxmox_virtual_environment_vm" "k8s_masters" {
  for_each = var.k8s_masters

  node_name = "pve1"
  vm_id     = var.vm_ids.masters + index(keys(var.k8s_masters), each.key)
  name      = each.key
  
  tags = ["kubernetes", "master", "control-plane"]

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  disk {
    datastore_id = "pve-data"
    interface    = "scsi0"
    size         = parseint(regex("(\\d+)", each.value.disk)[0], 10)
    file_format  = "raw"
  }

  clone {
    vm_id = var.vm_template_id
    full  = true
  }

  initialization {
    user_account {
      username = "ubuntu"
      password = "ubuntu"
      keys     = var.ssh_public_keys
    }

    ip_config {
      ipv4 {
        address = "${local.master_ips[each.key]}/24"
        gateway = var.network_gateway
      }
    }

    dns {
      servers = var.network_dns
      domain  = "k8s.local"
    }
  }
}

# Dedicated etcd Nodes
resource "proxmox_virtual_environment_vm" "etcd_nodes" {
  for_each = var.etcd_nodes

  node_name = "pve1"
  vm_id     = var.vm_ids.etcd + index(keys(var.etcd_nodes), each.key)
  name      = each.key
  
  tags = ["etcd", "database"]

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  disk {
    datastore_id = "pve-data"
    interface    = "scsi0"
    size         = parseint(regex("(\\d+)", each.value.disk)[0], 10)
    file_format  = "raw"
  }

  clone {
    vm_id = var.vm_template_id
    full  = true
  }

  initialization {
    user_account {
      username = "ubuntu"
      password = "ubuntu"
      keys     = var.ssh_public_keys
    }

    ip_config {
      ipv4 {
        address = "${local.etcd_ips[each.key]}/24"
        gateway = var.network_gateway
      }
    }

    dns {
      servers = var.network_dns
      domain  = "k8s.local"
    }
  }
}

# Kubernetes Worker Nodes
resource "proxmox_virtual_environment_vm" "k8s_workers" {
  for_each = var.k8s_workers

  node_name = "pve1"
  vm_id     = var.vm_ids.workers + index(keys(var.k8s_workers), each.key)
  name      = each.key
  
  tags = ["kubernetes", "worker"]

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  disk {
    datastore_id = "pve-data"
    interface    = "scsi0"
    size         = parseint(regex("(\\d+)", each.value.disk)[0], 10)
    file_format  = "raw"
  }

  clone {
    vm_id = var.vm_template_id
    full  = true
  }

  initialization {
    user_account {
      username = "ubuntu"
      password = "ubuntu"
      keys     = var.ssh_public_keys
    }

    ip_config {
      ipv4 {
        address = "${local.worker_ips[each.key]}/24"
        gateway = var.network_gateway
      }
    }

    dns {
      servers = var.network_dns
      domain  = "k8s.local"
    }
  }
}

# Infrastructure Services
resource "proxmox_virtual_environment_vm" "infrastructure" {
  for_each = var.infrastructure_services

  node_name = "pve1"
  vm_id     = var.vm_ids.infrastructure + index(keys(var.infrastructure_services), each.key)
  name      = each.key
  
  tags = ["infrastructure", "service"]

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  disk {
    datastore_id = "pve-data"
    interface    = "scsi0"
    size         = parseint(regex("(\\d+)", each.value.disk)[0], 10)
    file_format  = "raw"
  }

  clone {
    vm_id = var.vm_template_id
    full  = true
  }

  initialization {
    user_account {
      username = "ubuntu"
      password = "ubuntu"
      keys     = var.ssh_public_keys
    }

    ip_config {
      ipv4 {
        address = "${local.infrastructure_ips[each.key]}/24"
        gateway = var.network_gateway
      }
    }

    dns {
      servers = var.network_dns
      domain  = "k8s.local"
    }
  }
}

# ARM64 Kubernetes Worker Nodes for Raspberry Pi
resource "proxmox_virtual_environment_vm" "k8s_workers_pi" {
  for_each = var.k8s_workers_pi

  node_name = "pve2"
  vm_id     = var.vm_ids.workers_pi + index(keys(var.k8s_workers_pi), each.key)
  name      = each.key
  
  tags = ["kubernetes", "worker", "arm64", "edge"]

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = parseint(regex("(\\d+)", each.value.disk)[0], 10)
    file_format  = "raw"
  }

  clone {
    vm_id = var.vm_template_id
    full  = true
  }

  initialization {
    user_account {
      username = "ubuntu"
      password = "ubuntu"
      keys     = var.ssh_public_keys
    }

    ip_config {
      ipv4 {
        address = "${local.worker_pi_ips[each.key]}/24"
        gateway = var.network_gateway
      }
    }

    dns {
      servers = var.network_dns
      domain  = "k8s.local"
    }
  }
}