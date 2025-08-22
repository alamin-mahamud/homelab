# Example: Multiple VMs for different purposes
module "web_server" {
  source = "../"

  vm_name     = "web-server"
  vm_id       = 110
  target_node = "pve"
  vm_template = "ubuntu-24.04-template"

  vm_cores     = 2
  vm_memory    = 2048
  vm_disk_size = "20G"
  vm_storage   = "pve-data"

  vm_network_bridge = "vmbr0"
  vm_ip_address     = "10.1.0.110/24"
  vm_gateway        = "10.1.0.1"

  ssh_public_key   = file("~/.ssh/id_ed25519.pub")
  proxmox_password = var.proxmox_password
}

module "database_server" {
  source = "../"

  vm_name     = "database-server"
  vm_id       = 111
  target_node = "pve"
  vm_template = "ubuntu-24.04-template"

  vm_cores     = 4
  vm_memory    = 8192
  vm_disk_size = "50G"
  vm_storage   = "pve-data"

  vm_network_bridge = "vmbr0"
  vm_ip_address     = "10.1.0.111/24"
  vm_gateway        = "10.1.0.1"

  ssh_public_key   = file("~/.ssh/id_ed25519.pub")
  proxmox_password = var.proxmox_password
}

module "monitoring_server" {
  source = "../"

  vm_name     = "monitoring"
  vm_id       = 112
  target_node = "pve"
  vm_template = "ubuntu-24.04-template"

  vm_cores     = 2
  vm_memory    = 4096
  vm_disk_size = "30G"
  vm_storage   = "pve-data"

  vm_network_bridge = "vmbr0"
  vm_ip_address     = "10.1.0.112/24"
  vm_gateway        = "10.1.0.1"

  ssh_public_key   = file("~/.ssh/id_ed25519.pub")
  proxmox_password = var.proxmox_password
}