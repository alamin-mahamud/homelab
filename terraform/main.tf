resource "proxmox_vm_qemu" "vm" {
  name        = "test-ubuntu-vm"
  target_node = "pve1"
  clone       = "ubuntu-server"
  full_clone  = true
  cores       = 2
  memory      = 4000
  agent       = 1

  disk {
    storage = "local"
    size    = "50G"
    type    = "scsi"
    discard = "on"
  }

  network {
    model     = "virtio"
    bridge    = "vmbr0"
    firewall  = true
    link_down = false
  }
}
