# Proxmox VE Cluster Configuration
# This configuration sets up a complete Proxmox infrastructure with:
# - Multiple VM templates (Ubuntu, Kubernetes nodes)
# - Network configuration with VLANs
# - Storage pools
# - High Availability settings

terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = ">= 2.9.0"
    }
  }
}

# Variables
variable "proxmox_host" {
  description = "Proxmox server IP or hostname"
  type        = string
  default     = "192.168.1.100"
}

variable "proxmox_user" {
  description = "Proxmox user"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "cluster_name" {
  description = "Name of the Proxmox cluster"
  type        = string
  default     = "homelab-cluster"
}

# Local variables for organization
locals {
  vm_defaults = {
    target_node = "proxmox"
    onboot      = true
    agent       = true
    boot        = "order=scsi0;ide2;net0"
    scsihw      = "virtio-scsi-single"
    cores       = 2
    memory      = 4096
    disk_size   = "32G"
    disk_type   = "scsi"
    disk_storage = "local-lvm"
    network_bridge = "vmbr0"
    network_model  = "virtio"
  }

  k8s_nodes = {
    masters = 3
    workers = 3
  }
}

# Cloud-init template for Ubuntu VMs
resource "proxmox_vm_qemu" "ubuntu_template" {
  name        = "ubuntu-template"
  desc        = "Ubuntu 22.04 LTS Template"
  vmid        = 9000
  target_node = local.vm_defaults.target_node
  clone       = "none"
  
  iso         = "local:iso/ubuntu-22.04.3-live-server-amd64.iso"
  cores       = 2
  memory      = 2048
  
  disk {
    size    = "20G"
    type    = "scsi"
    storage = local.vm_defaults.disk_storage
  }
  
  network {
    model  = local.vm_defaults.network_model
    bridge = local.vm_defaults.network_bridge
  }
  
  lifecycle {
    ignore_changes = [disk, network]
  }
}

# Kubernetes Master Nodes
resource "proxmox_vm_qemu" "k8s_master" {
  count = local.k8s_nodes.masters
  
  name        = "k8s-master-${count.index + 1}"
  desc        = "Kubernetes Master Node ${count.index + 1}"
  vmid        = 100 + count.index
  target_node = local.vm_defaults.target_node
  
  clone       = proxmox_vm_qemu.ubuntu_template.name
  full_clone  = true
  
  cores       = 4
  memory      = 8192
  balloon     = 4096
  
  disk {
    size    = "50G"
    type    = local.vm_defaults.disk_type
    storage = local.vm_defaults.disk_storage
    iothread = true
  }
  
  network {
    model  = local.vm_defaults.network_model
    bridge = local.vm_defaults.network_bridge
    tag    = 10  # Kubernetes VLAN
  }
  
  # Cloud-init settings
  os_type    = "cloud-init"
  ipconfig0  = "ip=192.168.10.${10 + count.index}/24,gw=192.168.10.1"
  nameserver = "192.168.1.1"
  ciuser     = "ubuntu"
  sshkeys    = var.ssh_public_key
  
  # High Availability
  hastate    = "started"
  hagroup    = "k8s-masters"
  
  # Boot settings
  boot       = local.vm_defaults.boot
  onboot     = true
  agent      = 1
  
  lifecycle {
    create_before_destroy = true
  }
}

# Kubernetes Worker Nodes
resource "proxmox_vm_qemu" "k8s_worker" {
  count = local.k8s_nodes.workers
  
  name        = "k8s-worker-${count.index + 1}"
  desc        = "Kubernetes Worker Node ${count.index + 1}"
  vmid        = 200 + count.index
  target_node = local.vm_defaults.target_node
  
  clone       = proxmox_vm_qemu.ubuntu_template.name
  full_clone  = true
  
  cores       = 8
  memory      = 16384
  balloon     = 8192
  
  disk {
    size    = "100G"
    type    = local.vm_defaults.disk_type
    storage = local.vm_defaults.disk_storage
    iothread = true
  }
  
  # Additional disk for container storage
  disk {
    size    = "200G"
    type    = local.vm_defaults.disk_type
    storage = local.vm_defaults.disk_storage
    iothread = true
  }
  
  network {
    model  = local.vm_defaults.network_model
    bridge = local.vm_defaults.network_bridge
    tag    = 10  # Kubernetes VLAN
  }
  
  # Cloud-init settings
  os_type    = "cloud-init"
  ipconfig0  = "ip=192.168.10.${20 + count.index}/24,gw=192.168.10.1"
  nameserver = "192.168.1.1"
  ciuser     = "ubuntu"
  sshkeys    = var.ssh_public_key
  
  # Boot settings
  boot       = local.vm_defaults.boot
  onboot     = true
  agent      = 1
  
  lifecycle {
    create_before_destroy = true
  }
}

# Storage VM for TrueNAS
resource "proxmox_vm_qemu" "truenas" {
  name        = "truenas"
  desc        = "TrueNAS Storage Server"
  vmid        = 300
  target_node = local.vm_defaults.target_node
  
  cores       = 4
  memory      = 16384
  balloon     = 0  # Disable for ZFS
  
  # Boot disk
  disk {
    size    = "32G"
    type    = local.vm_defaults.disk_type
    storage = local.vm_defaults.disk_storage
  }
  
  # Storage disks - pass through if possible
  disk {
    size    = "1000G"
    type    = local.vm_defaults.disk_type
    storage = "zfs-storage"
  }
  
  disk {
    size    = "1000G"
    type    = local.vm_defaults.disk_type
    storage = "zfs-storage"
  }
  
  network {
    model  = local.vm_defaults.network_model
    bridge = local.vm_defaults.network_bridge
    tag    = 20  # Storage VLAN
  }
  
  # Additional network for storage traffic
  network {
    model  = local.vm_defaults.network_model
    bridge = "vmbr1"
    tag    = 30  # Storage backend VLAN
  }
  
  boot   = local.vm_defaults.boot
  onboot = true
}

# Development VM
resource "proxmox_vm_qemu" "dev_vm" {
  name        = "dev-environment"
  desc        = "Development Environment"
  vmid        = 400
  target_node = local.vm_defaults.target_node
  
  clone       = proxmox_vm_qemu.ubuntu_template.name
  full_clone  = true
  
  cores       = 8
  memory      = 32768
  balloon     = 16384
  
  disk {
    size    = "200G"
    type    = local.vm_defaults.disk_type
    storage = local.vm_defaults.disk_storage
    iothread = true
    ssd     = true
  }
  
  network {
    model  = local.vm_defaults.network_model
    bridge = local.vm_defaults.network_bridge
    tag    = 40  # Development VLAN
  }
  
  # Cloud-init settings
  os_type    = "cloud-init"
  ipconfig0  = "ip=192.168.40.10/24,gw=192.168.40.1"
  nameserver = "192.168.1.1"
  ciuser     = "developer"
  sshkeys    = var.ssh_public_key
  
  # Pass through GPU if available
  # hostpci {
  #   id   = "0000:01:00"
  #   pcie = true
  # }
  
  boot   = local.vm_defaults.boot
  onboot = false  # Start manually when needed
  agent  = 1
}

# Monitoring Stack VM
resource "proxmox_vm_qemu" "monitoring" {
  name        = "monitoring"
  desc        = "Prometheus, Grafana, Loki Stack"
  vmid        = 500
  target_node = local.vm_defaults.target_node
  
  clone       = proxmox_vm_qemu.ubuntu_template.name
  full_clone  = true
  
  cores       = 4
  memory      = 8192
  
  disk {
    size    = "100G"
    type    = local.vm_defaults.disk_type
    storage = local.vm_defaults.disk_storage
    iothread = true
  }
  
  network {
    model  = local.vm_defaults.network_model
    bridge = local.vm_defaults.network_bridge
    tag    = 50  # Management VLAN
  }
  
  os_type    = "cloud-init"
  ipconfig0  = "ip=192.168.50.10/24,gw=192.168.50.1"
  nameserver = "192.168.1.1"
  ciuser     = "ubuntu"
  sshkeys    = var.ssh_public_key
  
  boot   = local.vm_defaults.boot
  onboot = true
  agent  = 1
}

# Outputs
output "k8s_master_ips" {
  value = [
    for vm in proxmox_vm_qemu.k8s_master : {
      name = vm.name
      ip   = vm.default_ipv4_address
    }
  ]
  description = "Kubernetes master node IPs"
}

output "k8s_worker_ips" {
  value = [
    for vm in proxmox_vm_qemu.k8s_worker : {
      name = vm.name
      ip   = vm.default_ipv4_address
    }
  ]
  description = "Kubernetes worker node IPs"
}

output "dev_vm_ip" {
  value       = proxmox_vm_qemu.dev_vm.default_ipv4_address
  description = "Development VM IP address"
}

output "monitoring_vm_ip" {
  value       = proxmox_vm_qemu.monitoring.default_ipv4_address
  description = "Monitoring stack VM IP address"
}