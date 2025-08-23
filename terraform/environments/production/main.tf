# Production Environment Configuration
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 3.0"
    }
  }
  
  # Optional: Remote state backend
  # backend "s3" {
  #   bucket = "homelab-terraform-state"
  #   key    = "production/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

# Configure Proxmox Provider
provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = var.proxmox_tls_insecure
  pm_parallel         = 10
  pm_timeout          = 600
}

# Kubernetes Control Plane VMs
module "k8s_masters" {
  source = "../../modules/proxmox-vm"
  
  count = var.master_count
  
  vm_name         = "k8s-master-${count.index + 1}"
  vm_id           = 200 + count.index
  target_node     = var.proxmox_node
  vm_template     = var.vm_template_name
  
  vm_cores        = var.master_cores
  vm_memory       = var.master_memory
  vm_disk_size    = var.master_disk_size
  vm_storage      = var.vm_storage
  
  network_bridge  = var.network_bridge
  vm_ip_address   = cidrhost(var.k8s_network_cidr, 10 + count.index)
  vm_gateway      = var.network_gateway
  vm_dns          = join(",", var.network_dns)
  
  ssh_public_keys = var.ssh_public_keys
  
  tags = ["kubernetes", "master", var.environment]
  
  cloud_init_custom = templatefile("${path.module}/cloud-init/k8s-master.yaml", {
    hostname     = "k8s-master-${count.index + 1}"
    domain       = var.network_domain
    k8s_version  = var.k8s_version
    pod_subnet   = var.k8s_pod_subnet
    service_subnet = var.k8s_service_subnet
  })
}

# Kubernetes Worker Nodes
module "k8s_workers" {
  source = "../../modules/proxmox-vm"
  
  count = var.worker_count
  
  vm_name         = "k8s-worker-${count.index + 1}"
  vm_id           = 210 + count.index
  target_node     = var.proxmox_node
  vm_template     = var.vm_template_name
  
  vm_cores        = var.worker_cores
  vm_memory       = var.worker_memory
  vm_disk_size    = var.worker_disk_size
  vm_storage      = var.vm_storage
  
  network_bridge  = var.network_bridge
  vm_ip_address   = cidrhost(var.k8s_network_cidr, 20 + count.index)
  vm_gateway      = var.network_gateway
  vm_dns          = join(",", var.network_dns)
  
  ssh_public_keys = var.ssh_public_keys
  
  tags = ["kubernetes", "worker", var.environment]
  
  cloud_init_custom = templatefile("${path.module}/cloud-init/k8s-worker.yaml", {
    hostname     = "k8s-worker-${count.index + 1}"
    domain       = var.network_domain
    k8s_version  = var.k8s_version
  })
}

# Load Balancer for K8s API
module "k8s_lb" {
  source = "../../modules/proxmox-vm"
  
  vm_name         = "k8s-lb"
  vm_id           = 199
  target_node     = var.proxmox_node
  vm_template     = var.vm_template_name
  
  vm_cores        = 2
  vm_memory       = 2048
  vm_disk_size    = "20G"
  vm_storage      = var.vm_storage
  
  network_bridge  = var.network_bridge
  vm_ip_address   = cidrhost(var.k8s_network_cidr, 5)
  vm_gateway      = var.network_gateway
  vm_dns          = join(",", var.network_dns)
  
  ssh_public_keys = var.ssh_public_keys
  
  tags = ["kubernetes", "loadbalancer", var.environment]
  
  cloud_init_custom = templatefile("${path.module}/cloud-init/haproxy.yaml", {
    hostname = "k8s-lb"
    domain   = var.network_domain
    master_ips = [for i in range(var.master_count) : cidrhost(var.k8s_network_cidr, 10 + i)]
  })
}

# Storage/NFS Server (Optional)
module "storage_server" {
  source = "../../modules/proxmox-vm"
  
  count = var.deploy_storage ? 1 : 0
  
  vm_name         = "storage-nfs"
  vm_id           = 190
  target_node     = var.proxmox_node
  vm_template     = var.vm_template_name
  
  vm_cores        = 4
  vm_memory       = 8192
  vm_disk_size    = "500G"
  vm_storage      = var.vm_storage
  
  network_bridge  = var.network_bridge
  vm_ip_address   = cidrhost(var.k8s_network_cidr, 50)
  vm_gateway      = var.network_gateway
  vm_dns          = join(",", var.network_dns)
  
  ssh_public_keys = var.ssh_public_keys
  
  tags = ["storage", "nfs", var.environment]
  
  # Additional data disk for NFS exports
  additional_disks = [{
    size    = "1T"
    storage = var.vm_storage
    type    = "scsi"
    slot    = 1
  }]
}

# Generate Ansible Inventory
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/ansible-inventory.ini"
  content  = templatefile("${path.module}/templates/ansible-inventory.tpl", {
    masters = module.k8s_masters
    workers = module.k8s_workers
    lb      = module.k8s_lb
    storage = var.deploy_storage ? module.storage_server : []
    ssh_key = var.ssh_private_key_path
  })
}

# Output important information
output "k8s_cluster_info" {
  value = {
    load_balancer_ip = module.k8s_lb.vm_ip
    master_ips       = module.k8s_masters[*].vm_ip
    worker_ips       = module.k8s_workers[*].vm_ip
    storage_ip       = var.deploy_storage ? module.storage_server[0].vm_ip : null
    api_endpoint     = "https://${module.k8s_lb.vm_ip}:6443"
  }
}