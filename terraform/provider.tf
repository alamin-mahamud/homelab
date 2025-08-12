# Provider Configuration for Proxmox VE
# Supports both password and API token authentication

terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = ">= 2.9.0"
    }
  }
  
  # Optional: Configure backend for remote state
  # backend "s3" {
  #   bucket = "homelab-terraform-state"
  #   key    = "proxmox/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

# Provider configuration using password authentication (default)
provider "proxmox" {
  pm_api_url      = "https://${var.proxmox_host}:8006/api2/json"
  pm_tls_insecure = true  # Set to false in production with proper certificates
  
  # Choose authentication method:
  # Option 1: Password authentication
  pm_user     = var.proxmox_user
  pm_password = var.proxmox_password
  
  # Option 2: API token authentication (uncomment to use)
  # pm_api_token_id     = var.proxmox_api_token_id
  # pm_api_token_secret = var.proxmox_api_token_secret
  
  # Connection settings
  pm_timeout   = 600      # API timeout in seconds
  pm_parallel  = 10       # Parallel API requests
  
  # Debug logging (disable in production)
  pm_log_enable = true
  pm_log_file   = "terraform-plugin-proxmox.log"
  pm_log_levels = {
    _default    = "debug"
    _capturelog = ""
  }
}

# Optional: Additional provider for secondary cluster
# provider "proxmox" {
#   alias           = "backup"
#   pm_api_url      = "https://backup.proxmox.local:8006/api2/json"
#   pm_user         = var.backup_proxmox_user
#   pm_password     = var.backup_proxmox_password
#   pm_tls_insecure = true
# }