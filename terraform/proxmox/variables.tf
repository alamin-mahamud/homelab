variable "vm_name" {
  description = "Name of the VM"
  type        = string
  default     = "ubuntu-vm"
}

variable "vm_id" {
  description = "VM ID (must be unique)"
  type        = number
  default     = 100
}

variable "target_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

variable "vm_template" {
  description = "Template name for cloning"
  type        = string
  default     = "ubuntu-24.04-template"
}

variable "vm_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "vm_memory" {
  description = "Memory in MB"
  type        = number
  default     = 2048
}

variable "vm_disk_size" {
  description = "Disk size (e.g., 20G)"
  type        = string
  default     = "20G"
}

variable "vm_storage" {
  description = "Storage location"
  type        = string
  default     = "pve-data"
}

variable "vm_network_bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

variable "vm_ip_address" {
  description = "Static IP address (CIDR format, e.g., 10.1.0.100/24)"
  type        = string
  default     = "dhcp"
}

variable "vm_gateway" {
  description = "Gateway IP address"
  type        = string
  default     = "10.1.0.1"
}

variable "vm_dns" {
  description = "DNS server"
  type        = string
  default     = "8.8.8.8"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  default     = ""
}

variable "gpu_passthrough" {
  description = "Enable GPU passthrough"
  type        = bool
  default     = false
}

variable "gpu_device" {
  description = "GPU device ID for passthrough (e.g., 01:00)"
  type        = string
  default     = "01:00"
}