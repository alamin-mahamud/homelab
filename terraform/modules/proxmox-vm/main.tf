# Reusable Proxmox VM Module
terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 3.0"
    }
  }
}

# Create VM from template
resource "proxmox_vm_qemu" "vm" {
  name        = var.vm_name
  vmid        = var.vm_id
  target_node = var.target_node
  clone       = var.vm_template
  full_clone  = var.full_clone
  
  # VM Hardware Configuration
  cores    = var.vm_cores
  sockets  = var.vm_sockets
  memory   = var.vm_memory
  vcpus    = var.vm_cores * var.vm_sockets
  cpu      = var.cpu_type
  numa     = var.numa_enabled
  hotplug  = var.hotplug_features
  
  # Boot Configuration
  boot     = var.boot_order
  bootdisk = "scsi0"
  scsihw   = var.scsi_controller
  
  # Enable QEMU Agent
  agent = var.qemu_agent_enabled ? 1 : 0
  
  # OS Type
  os_type = var.os_type
  
  # Primary Disk
  disk {
    slot     = 0
    size     = var.vm_disk_size
    type     = "scsi"
    storage  = var.vm_storage
    iothread = var.disk_iothread
    cache    = var.disk_cache
    ssd      = var.disk_ssd
    discard  = var.disk_discard
  }
  
  # Additional Disks
  dynamic "disk" {
    for_each = var.additional_disks
    content {
      slot     = disk.value.slot
      size     = disk.value.size
      type     = disk.value.type
      storage  = disk.value.storage
      iothread = lookup(disk.value, "iothread", 1)
      cache    = lookup(disk.value, "cache", "writeback")
      ssd      = lookup(disk.value, "ssd", true)
      discard  = lookup(disk.value, "discard", "on")
    }
  }
  
  # Network Configuration
  dynamic "network" {
    for_each = var.network_interfaces
    content {
      model    = network.value.model
      bridge   = network.value.bridge
      tag      = lookup(network.value, "vlan_tag", null)
      firewall = lookup(network.value, "firewall", true)
      rate     = lookup(network.value, "rate_limit", null)
    }
  }
  
  # Default network if no interfaces specified
  dynamic "network" {
    for_each = length(var.network_interfaces) == 0 ? [1] : []
    content {
      model  = "virtio"
      bridge = var.network_bridge
    }
  }
  
  # Cloud-Init Configuration
  ciuser       = var.cloud_init_user
  cipassword   = var.cloud_init_password
  sshkeys      = join("\n", var.ssh_public_keys)
  ipconfig0    = var.vm_ip_address != "dhcp" ? "ip=${var.vm_ip_address}/${var.vm_netmask},gw=${var.vm_gateway}" : "ip=dhcp"
  nameserver   = var.vm_dns
  searchdomain = var.vm_domain
  
  # Custom Cloud-Init
  cicustom = var.cloud_init_custom != "" ? "user=local:snippets/${var.vm_name}-cloud-init.yaml" : ""
  
  # VGA Configuration
  vga {
    type   = var.vga_type
    memory = var.vga_memory
  }
  
  # Machine and BIOS Type
  machine = var.machine_type
  bios    = var.bios_type
  
  # HA Configuration
  hastate = var.ha_enabled ? "started" : null
  hagroup = var.ha_group
  
  # Tags
  tags = join(",", var.tags)
  
  # Protection and Startup
  protection = var.protection
  onboot     = var.start_on_boot
  startup    = var.startup_order != "" ? var.startup_order : null
  
  # Lifecycle Management
  lifecycle {
    ignore_changes = var.ignore_changes
  }
  
  # Provisioners
  provisioner "local-exec" {
    when    = create
    command = var.post_create_script != "" ? var.post_create_script : "echo 'VM ${var.vm_name} created'"
  }
  
  provisioner "local-exec" {
    when    = destroy
    command = var.pre_destroy_script != "" ? var.pre_destroy_script : "echo 'VM ${var.vm_name} will be destroyed'"
  }
}

# Create cloud-init snippet if custom config provided
resource "null_resource" "cloud_init_snippet" {
  count = var.cloud_init_custom != "" ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      echo '${var.cloud_init_custom}' > /tmp/${var.vm_name}-cloud-init.yaml
      scp /tmp/${var.vm_name}-cloud-init.yaml root@${var.proxmox_host}:/var/lib/vz/snippets/
      rm /tmp/${var.vm_name}-cloud-init.yaml
    EOT
  }
  
  triggers = {
    cloud_init_content = var.cloud_init_custom
  }
}