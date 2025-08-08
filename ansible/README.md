# Ansible Configuration

Ansible is used for infrastructure automation and configuration management in this homelab setup.

## Prerequisites

- Ansible installed on your control machine
- SSH access to all managed hosts
- Python installed on managed hosts

## Setup

### 1. Configure Inventory

Update the inventory files in `./inventories/` directory:
- `hosts/k8s.ini` - Kubernetes cluster nodes
- `hosts/etcd.ini` - ETCD cluster nodes

### 2. SSH Key Distribution

Copy your SSH public key to all managed hosts:
```bash
ssh-copy-id <host-ip>
```

### 3. Configuration Files

- `ansible.cfg` - Main Ansible configuration
- `inventories/group_vars/` - Group-specific variables
  - `all.yaml` - Global variables
  - `k8s_masters.yaml` - Kubernetes master nodes configuration
  - `k8s_workers.yaml` - Kubernetes worker nodes configuration

## Playbooks

### Kubernetes Cluster Deployment

Deploy a complete Kubernetes cluster:
```bash
ansible-playbook -i ./inventories/k8s.ini ./playbooks/k8s/deploy.yaml
```

Destroy Kubernetes cluster:
```bash
ansible-playbook -i ./inventories/k8s.ini ./playbooks/k8s/destroy.yaml
```

### ETCD Cluster

Deploy ETCD cluster with debug output:
```bash
ANSIBLE_STDOUT_CALLBACK=yaml ansible-playbook -i ./inventories/hosts/etcd.ini ./playbooks/etcd.yaml -e debug_mode=true
```

### Hello World Test

Run a simple connectivity test:
```bash
ansible-playbook -i ./inventories/k8s.ini ./playbooks/hello-world.yml
```

## Roles

### ETCD Role

The ETCD role manages the installation and configuration of ETCD clusters:
- **defaults/main.yml** - Default variables
- **files/etcd.service** - Systemd service file
- **tasks/** - Task definitions
  - `main.yml` - Main task entry point
  - `install.yml` - Installation tasks
  - `configure.yml` - Configuration tasks
  - `start.yml` - Service startup tasks
- **templates/etcd.conf.yml.j2** - ETCD configuration template

## Output Formats

For more readable output, you can use different callback plugins:
```bash
# YAML format output
ANSIBLE_STDOUT_CALLBACK=yaml ansible-playbook ...

# JSON format output
ANSIBLE_STDOUT_CALLBACK=json ansible-playbook ...
```

## Troubleshooting

### Common Issues

1. **SSH Connection Failed**
   - Ensure SSH keys are properly distributed
   - Check network connectivity
   - Verify SSH service is running on target hosts

2. **Python Not Found**
   - Install Python on managed hosts
   - Configure `ansible_python_interpreter` in inventory

3. **Permission Denied**
   - Ensure proper sudo permissions
   - Use `--become` flag when needed

### Debug Mode

Enable verbose output for debugging:
```bash
ansible-playbook -vvv -i ./inventories/k8s.ini ./playbooks/k8s/deploy.yaml
```

## Best Practices

- Always test playbooks in a development environment first
- Use `--check` flag for dry runs
- Keep sensitive data in Ansible Vault
- Use version control for all playbooks and configurations
- Document custom roles and playbooks