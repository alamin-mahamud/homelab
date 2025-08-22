# Example: VM with GPU Passthrough for AI/ML workloads
module "gpu_vm" {
  source = "../"

  # VM Configuration
  vm_name     = "ai-workstation"
  vm_id       = 200
  target_node = "pve"
  vm_template = "ubuntu-24.04-template"

  # High-performance configuration
  vm_cores     = 8
  vm_memory    = 16384  # 16GB
  vm_disk_size = "100G"
  vm_storage   = "pve-data"

  # Network
  vm_network_bridge = "vmbr0"
  vm_ip_address     = "10.1.0.200/24"
  vm_gateway        = "10.1.0.1"
  vm_dns           = "8.8.8.8"

  # GPU Passthrough
  gpu_passthrough = true
  gpu_device     = "01:00"  # NVIDIA RTX 4080 SUPER

  # SSH Access
  ssh_public_key = file("~/.ssh/id_ed25519.pub")

  # Proxmox credentials
  proxmox_password = var.proxmox_password
}