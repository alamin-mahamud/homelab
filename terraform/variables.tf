# Production-ready Kubernetes Infrastructure Variables

# Proxmox Configuration
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://10.1.0.0:8006/api2/json"
}

variable "proxmox_user" {
  description = "Proxmox username"
  type        = string
  default     = "terraform@pve"
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

# SSH Configuration
variable "ssh_public_keys" {
  description = "List of SSH public keys"
  type        = list(string)
}

# Network Configuration
variable "network_gateway" {
  description = "Network gateway"
  type        = string
  default     = "10.1.1.1"
}

variable "network_cidr" {
  description = "Network CIDR for all VMs"
  type        = string
  default     = "10.1.1.0/24"
}

variable "network_dns" {
  description = "DNS servers"
  type        = list(string)
  default     = ["8.8.8.8", "1.1.1.1"]
}

# VM Template
variable "vm_template" {
  description = "VM template name"
  type        = string
  default     = "ubuntu-24.04-template"
}

variable "vm_template_id" {
  description = "VM template ID"
  type        = number
  default     = 999
}

# Cluster Configuration
variable "k8s_masters" {
  description = "Kubernetes master nodes configuration"
  type = map(object({
    cores  = number
    memory = number
    disk   = string
  }))
  default = {
    "k8s-master-01" = { cores = 4, memory = 8192, disk = "50G" }
    "k8s-master-02" = { cores = 4, memory = 8192, disk = "50G" }
    "k8s-master-03" = { cores = 4, memory = 8192, disk = "50G" }
  }
}

variable "etcd_nodes" {
  description = "Dedicated etcd nodes configuration"
  type = map(object({
    cores  = number
    memory = number
    disk   = string
  }))
  default = {
    "etcd-01" = { cores = 2, memory = 4096, disk = "30G" }
    "etcd-02" = { cores = 2, memory = 4096, disk = "30G" }
    "etcd-03" = { cores = 2, memory = 4096, disk = "30G" }
  }
}

variable "k8s_workers" {
  description = "Kubernetes worker nodes configuration"
  type = map(object({
    cores  = number
    memory = number
    disk   = string
  }))
  default = {
    "k8s-worker-01" = { cores = 4, memory = 8192, disk = "50G" }
    "k8s-worker-02" = { cores = 4, memory = 8192, disk = "50G" }
    "k8s-worker-03" = { cores = 4, memory = 8192, disk = "50G" }
    "k8s-worker-04" = { cores = 4, memory = 8192, disk = "50G" }
    "k8s-worker-05" = { cores = 4, memory = 8192, disk = "50G" }
    "k8s-worker-06" = { cores = 4, memory = 8192, disk = "50G" }
    "k8s-worker-07" = { cores = 4, memory = 8192, disk = "50G" }
    "k8s-worker-08" = { cores = 4, memory = 8192, disk = "50G" }
    "k8s-worker-09" = { cores = 4, memory = 8192, disk = "50G" }
    "k8s-worker-10" = { cores = 4, memory = 8192, disk = "50G" }
  }
}

variable "k8s_workers_pi" {
  description = "Kubernetes worker nodes for Raspberry Pi (ARM64)"
  type = map(object({
    cores  = number
    memory = number
    disk   = string
  }))
  default = {
    "k8s-worker-pi-01" = { cores = 2, memory = 3072, disk = "15G" }
    "k8s-worker-pi-02" = { cores = 2, memory = 3072, disk = "15G" }
  }
}

# Infrastructure Services
variable "infrastructure_services" {
  description = "Infrastructure services configuration"
  type = map(object({
    cores  = number
    memory = number
    disk   = string
  }))
  default = {
    "haproxy-lb"        = { cores = 2, memory = 4096, disk = "30G" }
    "truenas"           = { cores = 4, memory = 16384, disk = "100G" }
    "proxmox-backup"    = { cores = 4, memory = 8192, disk = "200G" }
  }
}

# VM ID and IP Ranges
variable "vm_ids" {
  description = "VM ID allocation"
  type = object({
    masters       = number
    etcd         = number
    workers      = number
    workers_pi    = number
    infrastructure = number
  })
  default = {
    masters       = 2001  # 2001-2003
    etcd         = 2010  # 2010-2012
    workers      = 2020  # 2020-2029
    workers_pi    = 2040  # 2040-2041 (ARM64 workers)
    infrastructure = 2030  # 2030-2032
  }
}

variable "ip_ranges" {
  description = "IP address ranges for VMs"
  type = object({
    masters       = number
    etcd         = number
    workers      = number
    workers_pi    = number
    infrastructure = number
  })
  default = {
    masters       = 11  # 10.1.1.11-13
    etcd         = 21  # 10.1.1.21-23
    workers      = 31  # 10.1.1.31-40
    workers_pi    = 60  # 10.1.1.60-61 (ARM64 workers)
    infrastructure = 50  # 10.1.1.50-52
  }
}