# Proxmox Provider Variables
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://10.1.0.0:8006/api2/json"
}

variable "proxmox_user" {
  description = "Proxmox user"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification"
  type        = bool
  default     = true
}

variable "proxmox_nodes" {
  description = "List of Proxmox nodes for VM distribution"
  type        = list(string)
  default     = ["pve", "rpi-node"]
}

variable "proxmox_node" {
  description = "Primary Proxmox node (for backward compatibility)"
  type        = string
  default     = "pve"
}

# Template Configuration
variable "vm_template_name" {
  description = "Name of the VM template to clone"
  type        = string
  default     = "ubuntu-cloud-template"
}

variable "vm_storage" {
  description = "Storage pool for VMs"
  type        = string
  default     = "local-lvm"
}

# Network Configuration
variable "network_bridge" {
  description = "Network bridge for VMs"
  type        = string
  default     = "vmbr0"
}

variable "network_gateway" {
  description = "Network gateway"
  type        = string
  default     = "10.1.1.1"
}

variable "network_dns" {
  description = "DNS servers"
  type        = list(string)
  default     = ["10.1.0.1", "1.1.1.1", "8.8.8.8"]
}

variable "network_domain" {
  description = "Network domain"
  type        = string
  default     = "homelab.local"
}

variable "k8s_network_cidr" {
  description = "CIDR for Kubernetes nodes"
  type        = string
  default     = "10.1.1.0/24"
}

# Kubernetes Configuration
variable "k8s_version" {
  description = "Kubernetes version to install"
  type        = string
  default     = "1.29.0"
}

variable "k8s_pod_subnet" {
  description = "Kubernetes pod network subnet"
  type        = string
  default     = "10.244.0.0/16"
}

variable "k8s_service_subnet" {
  description = "Kubernetes service network subnet"
  type        = string
  default     = "10.96.0.0/12"
}

# Master Node Configuration
variable "master_count" {
  description = "Number of master nodes"
  type        = number
  default     = 3
}

variable "master_cores" {
  description = "CPU cores for master nodes"
  type        = number
  default     = 4
}

variable "master_memory" {
  description = "Memory for master nodes (MB)"
  type        = number
  default     = 8192
}

variable "master_disk_size" {
  description = "Disk size for master nodes"
  type        = string
  default     = "100G"
}

# Worker Node Configuration
variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 11
}

variable "worker_cores" {
  description = "CPU cores for worker nodes"
  type        = number
  default     = 4
}

variable "worker_memory" {
  description = "Memory for worker nodes (MB)"
  type        = number
  default     = 16384
}

variable "worker_disk_size" {
  description = "Disk size for worker nodes"
  type        = string
  default     = "200G"
}

# SSH Configuration
variable "ssh_public_keys" {
  description = "SSH public keys for VM access"
  type        = list(string)
  default     = []
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for Ansible"
  type        = string
  default     = "~/.ssh/homelab_rsa"
}

# Optional Components
variable "deploy_storage" {
  description = "Deploy NFS storage server"
  type        = bool
  default     = true
}

# Environment
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}