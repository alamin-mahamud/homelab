# Proxmox Terraform Templates

This directory contains Terraform configurations for managing Proxmox VMs with support for GPU passthrough.

## Prerequisites

1. **Proxmox VE 8.4+** with IOMMU enabled for GPU passthrough
2. **Terraform** >= 1.0
3. **Ubuntu 24.04 template** created in Proxmox

## GPU Passthrough Status

✅ **GPU Passthrough Ready**: Your Proxmox server is properly configured for GPU passthrough:
- AMD Ryzen 9 7950X with AMD-Vi IOMMU enabled
- NVIDIA GeForce RTX 4080 SUPER in isolated IOMMU group 12
- Kernel parameters: `amd_iommu=on iommu=pt`
- 49 IOMMU groups detected

## Quick Start

### 1. Create Ubuntu 24.04 Template

Run the template creation script on your Proxmox host:

```bash
# SSH to Proxmox server
ssh root@10.1.0.0

# Create template (VMID 999)
./scripts/create-template.sh 999
```

### 2. Configure Terraform

```bash
# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit with your settings
nano terraform.tfvars
```

Required variables:
```hcl
proxmox_password = "your-proxmox-root-password"
ssh_public_key   = "ssh-ed25519 AAAAC3... your-key"
```

### 3. Deploy VM

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply configuration
terraform apply
```

## Configuration Options

### Basic VM
```hcl
vm_name      = "ubuntu-dev"
vm_cores     = 2
vm_memory    = 2048
vm_disk_size = "20G"
vm_ip_address = "dhcp"  # or "10.1.0.100/24"
```

### GPU Passthrough VM
```hcl
gpu_passthrough = true
gpu_device     = "01:00"  # NVIDIA RTX 4080 SUPER
vm_cores       = 8
vm_memory      = 16384
```

## Storage Configuration

Available storage pools:
- `pve-data` - Main VM storage
- `pve-shared` - Shared storage
- `local` - Local storage
- `shared-iso` - ISO images

## Network Configuration

Default network bridge: `vmbr0`

Static IP example:
```hcl
vm_ip_address = "10.1.0.100/24"
vm_gateway    = "10.1.0.1"
vm_dns        = "8.8.8.8"
```

## Examples

### Single VM
```bash
terraform apply -var="vm_name=test-vm" -var="vm_id=101"
```

### GPU Workstation
```bash
terraform apply -var-file="examples/gpu-workstation.tfvars"
```

### Multiple VMs
See `examples/multi-vm.tf` for deploying multiple VMs simultaneously.

## GPU Passthrough Requirements

For GPU passthrough VMs, ensure:

1. **IOMMU enabled** (✅ already configured)
2. **GPU in isolated group** (✅ group 12)
3. **VFIO modules loaded**:
   ```bash
   # Add to /etc/modules
   vfio
   vfio_iommu_type1
   vfio_pci
   vfio_virqfd
   ```

4. **GPU bound to VFIO**:
   ```bash
   # Add to /etc/modprobe.d/vfio.conf
   options vfio-pci ids=10de:2783,10de:22bc
   ```

5. **Blacklist GPU drivers**:
   ```bash
   # Add to /etc/modprobe.d/blacklist.conf
   blacklist nouveau
   blacklist nvidia
   ```

## Troubleshooting

### Common Issues

1. **Template not found**:
   ```bash
   pvesh get /nodes/pve/qemu
   ```

2. **Storage not available**:
   ```bash
   pvesh get /storage
   ```

3. **Network bridge issues**:
   ```bash
   ip link show
   ```

### GPU Passthrough Issues

1. **Check IOMMU groups**:
   ```bash
   find /sys/kernel/iommu_groups/ -type l
   ```

2. **Verify GPU isolation**:
   ```bash
   lspci -nnv | grep -A 15 "VGA\|3D"
   ```

3. **Check VFIO binding**:
   ```bash
   lspci -k | grep -A 3 "VGA\|3D"
   ```

## VM Management

### Connect to VM
```bash
# Get IP from Terraform output
terraform output vm_ip

# SSH to VM
ssh ubuntu@$(terraform output -raw vm_ip)
```

### VM Operations
```bash
# Start VM
qm start $(terraform output -raw vm_id)

# Stop VM
qm stop $(terraform output -raw vm_id)

# Console access
qm terminal $(terraform output -raw vm_id)
```

## Cleanup

```bash
# Destroy VM
terraform destroy

# Remove template (if needed)
qm destroy 999
```

## Advanced Configuration

### Custom Cloud-Init
Modify the `user_data` in `main.tf` to add custom cloud-init configuration.

### Multiple NICs
Add additional network blocks for multiple network interfaces.

### Additional Storage
Add more disk configurations for additional storage volumes.

## Support

- Proxmox VE Documentation: https://pve.proxmox.com/wiki/
- Terraform Proxmox Provider: https://github.com/Telmate/terraform-provider-proxmox
- GPU Passthrough Guide: https://pve.proxmox.com/wiki/PCI_Passthrough