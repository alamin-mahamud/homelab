# Windows 11 Desktop VM with GPU Passthrough
# This configuration creates a Windows 11 VM with RTX 4080 SUPER passthrough

resource "proxmox_vm_qemu" "windows_desktop" {
  name        = "windows-11-desktop"
  vmid        = 900
  target_node = "pve"
  
  # VM Configuration optimized for Windows + GPU
  cores    = 4
  sockets  = 1
  memory   = 16384  # 16GB
  vcpus    = 4
  cpu      = "host"
  numa     = true
  hotplug  = "network,disk,usb"
  
  # Windows 11 specific settings
  machine  = "q35"
  bios     = "ovmf"
  ostype   = "win11"
  
  # Boot configuration
  boot     = "order=scsi0"
  scsihw   = "virtio-scsi-pci"
  
  # Enable QEMU agent for Windows
  agent = 1

  # Primary storage disk (50GB NVMe-style)
  disk {
    slot     = 0
    size     = "50G"
    type     = "scsi"
    storage  = "pve-data"
    iothread = 1
    cache    = "writeback"
    discard  = "on"
  }

  # EFI disk for UEFI boot (required for Windows 11 + GPU passthrough)
  disk {
    slot    = 30
    type    = "efidisk0"
    storage = "pve-data"
    size    = "4M"
  }

  # Network configuration
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  # GPU Passthrough - RTX 4080 SUPER
  hostpci {
    host   = "01:00"
    pcie   = 1
    rombar = 1
    xvga   = 1
  }

  # VGA disabled since GPU handles display
  vga = "none"

  # TPM 2.0 for Windows 11 requirements
  tpmstate0 = "pve-data:1,version=v2.0"

  # Additional Windows optimizations
  balloon = 0  # Disable memory ballooning for performance

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

# Output information
output "windows_vm_id" {
  value = proxmox_vm_qemu.windows_desktop.vmid
}

output "windows_vm_name" {
  value = proxmox_vm_qemu.windows_desktop.name
}

output "windows_vm_status" {
  value = "VM created successfully. Manual steps required:"
  description = <<-EOT
    1. Download Windows 11 ISO from Microsoft
    2. Upload to /var/lib/vz/template/iso/ on Proxmox
    3. Attach ISO: qm set ${proxmox_vm_qemu.windows_desktop.vmid} --ide0 local:iso/Windows11.iso,media=cdrom
    4. Start VM: qm start ${proxmox_vm_qemu.windows_desktop.vmid}
    5. Install Windows 11 with VirtIO drivers
    6. Install NVIDIA RTX 4080 SUPER drivers
  EOT
}