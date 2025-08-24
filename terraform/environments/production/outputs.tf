# Terraform Outputs for HomeLab Infrastructure

output "cluster_info" {
  value = {
    masters = {
      for name, config in local.k8s_masters : name => {
        ip   = config.ip_address
        vmid = config.vmid
        tags = config.tags
      }
    }
    workers = {
      for name, config in local.k8s_workers : name => {
        ip   = config.ip_address
        vmid = config.vmid
        tags = config.tags
      }
    }
  }
}

output "load_balancer_vip" {
  value       = cidrhost(var.k8s_network_cidr, 9)
  description = "Virtual IP for K8s API access through HAProxy"
}

output "ansible_inventory" {
  value = templatefile("${path.module}/templates/ansible-inventory.tpl", {
    masters    = local.k8s_masters
    workers    = local.k8s_workers
    haproxy    = [for i in range(2) : {
      name = "haproxy-${format("%02d", i + 1)}"
      ip   = cidrhost(var.k8s_network_cidr, 10 + i)
    }]
    storage_ip = var.deploy_storage ? cidrhost(var.k8s_network_cidr, 5) : null
    gitlab_ip  = cidrhost(var.k8s_network_cidr, 107)
    monitoring_ip = cidrhost(var.k8s_network_cidr, 100)
    database_ip = cidrhost(var.k8s_network_cidr, 6)
  })
}