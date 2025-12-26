# Infrastructure Outputs

output "k8s_masters" {
  description = "Kubernetes master nodes"
  value = {
    for name, vm in proxmox_virtual_environment_vm.k8s_masters : name => {
      id = vm.vm_id
      ip = local.master_ips[name]
      name = vm.name
    }
  }
}

output "etcd_nodes" {
  description = "Dedicated etcd nodes"
  value = {
    for name, vm in proxmox_virtual_environment_vm.etcd_nodes : name => {
      id = vm.vm_id
      ip = local.etcd_ips[name]
      name = vm.name
    }
  }
}

output "k8s_workers" {
  description = "Kubernetes worker nodes"
  value = {
    for name, vm in proxmox_virtual_environment_vm.k8s_workers : name => {
      id = vm.vm_id
      ip = local.worker_ips[name]
      name = vm.name
    }
  }
}

output "infrastructure_services" {
  description = "Infrastructure services"
  value = {
    for name, vm in proxmox_virtual_environment_vm.infrastructure : name => {
      id = vm.vm_id
      ip = local.infrastructure_ips[name]
      name = vm.name
    }
  }
}

output "ansible_inventory" {
  description = "Ansible inventory in INI format"
  value = templatefile("${path.module}/templates/inventory.tpl", {
    masters = {
      for name, vm in proxmox_virtual_environment_vm.k8s_masters : name => {
        ip = local.master_ips[name]
        hostname = vm.name
      }
    }
    etcd_nodes = {
      for name, vm in proxmox_virtual_environment_vm.etcd_nodes : name => {
        ip = local.etcd_ips[name]
        hostname = vm.name
      }
    }
    workers = {
      for name, vm in proxmox_virtual_environment_vm.k8s_workers : name => {
        ip = local.worker_ips[name]
        hostname = vm.name
      }
    }
    infrastructure = {
      for name, vm in proxmox_virtual_environment_vm.infrastructure : name => {
        ip = local.infrastructure_ips[name]
        hostname = vm.name
      }
    }
  })
}