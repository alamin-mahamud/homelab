# VM Basic Configuration
variable "vm_name" {
  description = "Name of the VM"
  type        = string
}

variable "vm_id" {
  description = "VM ID in Proxmox"
  type        = number
}

variable "target_node" {
  description = "Target Proxmox node"
  type        = string
}

variable "vm_template" {
  description = "Template to clone from"
  type        = string
}

variable "full_clone" {
  description = "Create a full clone instead of linked clone"
  type        = bool
  default     = true
}

# Hardware Configuration
variable "vm_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "vm_sockets" {
  description = "Number of CPU sockets"
  type        = number
  default     = 1
}

variable "vm_memory" {
  description = "Memory in MB"
  type        = number
  default     = 2048
}

variable "cpu_type" {
  description = "CPU type"
  type        = string
  default     = "host"
}

variable "numa_enabled" {
  description = "Enable NUMA"
  type        = bool
  default     = true
}

variable "hotplug_features" {
  description = "Hotplug features to enable"
  type        = string
  default     = "network,disk,usb,memory,cpu"
}

# Disk Configuration
variable "vm_disk_size" {
  description = "Primary disk size"
  type        = string
  default     = "32G"
}

variable "vm_storage" {
  description = "Storage pool for the VM"
  type        = string
  default     = "local-lvm"
}

variable "scsi_controller" {
  description = "SCSI controller type"
  type        = string
  default     = "virtio-scsi-pci"
}

variable "disk_iothread" {
  description = "Enable IO thread for disk"
  type        = number
  default     = 1
}

variable "disk_cache" {
  description = "Disk cache mode"
  type        = string
  default     = "writeback"
}

variable "disk_ssd" {
  description = "Emulate SSD"
  type        = bool
  default     = true
}

variable "disk_discard" {
  description = "Enable discard/TRIM"
  type        = string
  default     = "on"
}

variable "additional_disks" {
  description = "Additional disks to attach"
  type = list(object({
    size    = string
    storage = string
    type    = string
    slot    = number
  }))
  default = []
}

# Network Configuration
variable "network_bridge" {
  description = "Default network bridge"
  type        = string
  default     = "vmbr0"
}

variable "network_interfaces" {
  description = "Network interfaces configuration"
  type = list(object({
    model     = string
    bridge    = string
    vlan_tag  = optional(number)
    firewall  = optional(bool)
    rate_limit = optional(number)
  }))
  default = []
}

variable "vm_ip_address" {
  description = "IP address for the VM (use 'dhcp' for DHCP)"
  type        = string
  default     = "dhcp"
}

variable "vm_netmask" {
  description = "Network mask (CIDR notation)"
  type        = number
  default     = 24
}

variable "vm_gateway" {
  description = "Network gateway"
  type        = string
  default     = ""
}

variable "vm_dns" {
  description = "DNS servers"
  type        = string
  default     = ""
}

variable "vm_domain" {
  description = "Search domain"
  type        = string
  default     = ""
}

# Cloud-Init Configuration
variable "cloud_init_user" {
  description = "Default user for cloud-init"
  type        = string
  default     = "ubuntu"
}

variable "cloud_init_password" {
  description = "Default password for cloud-init user"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_public_keys" {
  description = "SSH public keys to inject"
  type        = list(string)
  default     = []
}

variable "cloud_init_custom" {
  description = "Custom cloud-init configuration"
  type        = string
  default     = ""
}

# Display Configuration
variable "vga_type" {
  description = "VGA type"
  type        = string
  default     = "std"
}

variable "vga_memory" {
  description = "VGA memory in MB"
  type        = number
  default     = 16
}

# System Configuration
variable "machine_type" {
  description = "Machine type (pc or q35)"
  type        = string
  default     = "q35"
}

variable "bios_type" {
  description = "BIOS type (seabios or ovmf)"
  type        = string
  default     = "seabios"
}

variable "boot_order" {
  description = "Boot order"
  type        = string
  default     = "c"
}

variable "os_type" {
  description = "OS type for optimization"
  type        = string
  default     = "cloud-init"
}

variable "qemu_agent_enabled" {
  description = "Enable QEMU guest agent"
  type        = bool
  default     = true
}

# High Availability
variable "ha_enabled" {
  description = "Enable HA for this VM"
  type        = bool
  default     = false
}

variable "ha_group" {
  description = "HA group name"
  type        = string
  default     = ""
}

# VM Management
variable "protection" {
  description = "Protect VM from accidental deletion"
  type        = bool
  default     = false
}

variable "start_on_boot" {
  description = "Start VM on node boot"
  type        = bool
  default     = true
}

variable "startup_order" {
  description = "Startup order (format: 'order=1,up=30,down=30')"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags for the VM"
  type        = list(string)
  default     = []
}

# Lifecycle Management
variable "ignore_changes" {
  description = "List of attributes to ignore changes"
  type        = list(string)
  default     = ["network", "desc"]
}

# Scripts
variable "post_create_script" {
  description = "Script to run after VM creation"
  type        = string
  default     = ""
}

variable "pre_destroy_script" {
  description = "Script to run before VM destruction"
  type        = string
  default     = ""
}

# Proxmox Connection (for cloud-init snippet upload)
variable "proxmox_host" {
  description = "Proxmox host IP for snippet upload"
  type        = string
  default     = ""
}