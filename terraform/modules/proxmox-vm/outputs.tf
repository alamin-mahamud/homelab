# VM Information Outputs
output "vm_id" {
  description = "VM ID in Proxmox"
  value       = proxmox_vm_qemu.vm.vmid
}

output "vm_name" {
  description = "VM name"
  value       = proxmox_vm_qemu.vm.name
}

output "vm_ip" {
  description = "Primary IP address of the VM"
  value       = proxmox_vm_qemu.vm.default_ipv4_address
}

output "vm_mac" {
  description = "MAC address of the primary network interface"
  value       = try(proxmox_vm_qemu.vm.network[0].macaddr, "")
}

output "vm_node" {
  description = "Proxmox node where VM is running"
  value       = proxmox_vm_qemu.vm.target_node
}

output "vm_status" {
  description = "Current status of the VM"
  value       = proxmox_vm_qemu.vm.status
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = var.vm_ip_address != "dhcp" ? "ssh ${var.cloud_init_user}@${var.vm_ip_address}" : "ssh ${var.cloud_init_user}@${proxmox_vm_qemu.vm.default_ipv4_address}"
}

output "vm_specs" {
  description = "VM specifications"
  value = {
    cores    = var.vm_cores
    memory   = var.vm_memory
    disk     = var.vm_disk_size
    storage  = var.vm_storage
  }
}