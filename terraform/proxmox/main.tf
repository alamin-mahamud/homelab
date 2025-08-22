resource "proxmox_vm_qemu" "ubuntu_vm" {
  name        = var.vm_name
  vmid        = var.vm_id
  target_node = var.target_node
  clone       = var.vm_template
  
  # VM Configuration
  cores    = var.vm_cores
  sockets  = 1
  memory   = var.vm_memory
  vcpus    = var.vm_cores
  cpu      = "host"
  numa     = true
  hotplug  = "network,disk,usb"
  
  # Boot configuration
  boot     = "c"
  bootdisk = "scsi0"
  scsihw   = "virtio-scsi-pci"
  
  # Enable QEMU agent
  agent = 1

  # Primary disk
  disk {
    slot     = 0
    size     = var.vm_disk_size
    type     = "scsi"
    storage  = var.vm_storage
    iothread = 1
    cache    = "writeback"
  }

  # Network configuration
  network {
    model  = "virtio"
    bridge = var.vm_network_bridge
  }

  # Cloud-init configuration
  os_type      = "cloud-init"
  ciuser       = "ubuntu"
  cipassword   = "ubuntu"
  sshkeys      = var.ssh_public_key
  
  # Network configuration for cloud-init
  ipconfig0 = var.vm_ip_address != "dhcp" ? "ip=${var.vm_ip_address},gw=${var.vm_gateway}" : "ip=dhcp"
  nameserver = var.vm_dns

  # GPU Passthrough configuration (conditional)
  dynamic "hostpci" {
    for_each = var.gpu_passthrough ? [1] : []
    content {
      host   = var.gpu_device
      pcie   = 1
      rombar = 1
    }
  }

  # VGA configuration
  vga {
    type   = var.gpu_passthrough ? "none" : "std"
    memory = var.gpu_passthrough ? 0 : 4
  }

  # Machine type for GPU passthrough
  machine = var.gpu_passthrough ? "q35" : "pc"

  # BIOS configuration for GPU passthrough
  bios = var.gpu_passthrough ? "ovmf" : "seabios"

  # Lifecycle configuration
  lifecycle {
    ignore_changes = [
      network,
      desc,
      numa,
      tablet,
      boot,
      bootdisk,
      agent,
    ]
  }
}

# Output VM information
output "vm_ip" {
  value = proxmox_vm_qemu.ubuntu_vm.default_ipv4_address
}

output "vm_id" {
  value = proxmox_vm_qemu.ubuntu_vm.vmid
}

output "vm_name" {
  value = proxmox_vm_qemu.ubuntu_vm.name
}

output "ssh_command" {
  value = "ssh ubuntu@${proxmox_vm_qemu.ubuntu_vm.default_ipv4_address}"
}