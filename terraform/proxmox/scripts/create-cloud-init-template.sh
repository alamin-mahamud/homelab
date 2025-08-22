#!/bin/bash

# Advanced Ubuntu 24.04 Cloud-Init Template Creation Script for Proxmox
# This script creates a proper cloud-init enabled template

set -e

# Configuration
VMID=${1:-999}
VM_NAME="ubuntu-24.04-template"
STORAGE="pve-data"
MEMORY=2048
CORES=2
DISK_SIZE=20G
BRIDGE="vmbr0"

# Ubuntu 24.04 Cloud Image
CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/daily/server/jammy/current/jammy-server-cloudimg-amd64.img"
CLOUD_IMAGE_FILE="/tmp/jammy-server-cloudimg-amd64.img"

echo "Creating Ubuntu 24.04 Cloud-Init Template (VMID: $VMID)..."

# Download Ubuntu cloud image if not exists
if [ ! -f "$CLOUD_IMAGE_FILE" ]; then
    echo "Downloading Ubuntu 24.04 cloud image..."
    wget -O "$CLOUD_IMAGE_FILE" "$CLOUD_IMAGE_URL"
fi

# Create VM
echo "Creating VM $VMID..."
qm create $VMID \
  --name "$VM_NAME" \
  --memory $MEMORY \
  --cores $CORES \
  --net0 virtio,bridge=$BRIDGE \
  --scsihw virtio-scsi-pci \
  --scsi0 $STORAGE:0,import-from=$CLOUD_IMAGE_FILE \
  --ide2 $STORAGE:cloudinit \
  --boot order=scsi0 \
  --serial0 socket \
  --vga serial0 \
  --agent enabled=1,fstrim_cloned_disks=1

# Resize the disk
echo "Resizing disk to $DISK_SIZE..."
qm disk resize $VMID scsi0 $DISK_SIZE

# Set cloud-init defaults
echo "Configuring cloud-init..."
qm set $VMID --ciuser ubuntu
qm set $VMID --cipassword ubuntu
qm set $VMID --ipconfig0 ip=dhcp
qm set $VMID --nameserver "8.8.8.8 1.1.1.1"
qm set $VMID --searchdomain local

# Enable QEMU Guest Agent
qm set $VMID --agent enabled=1

# Set machine type for better compatibility
qm set $VMID --machine q35

# Set CPU type
qm set $VMID --cpu host

# Convert to template
echo "Converting to template..."
qm template $VMID

echo "✅ Template '$VM_NAME' created successfully with VMID $VMID"
echo ""
echo "Template configuration:"
qm config $VMID

echo ""
echo "🚀 You can now use this template with Terraform:"
echo "   vm_template = \"$VM_NAME\""
echo ""
echo "📋 Next steps:"
echo "   1. Copy terraform.tfvars.example to terraform.tfvars"
echo "   2. Set your proxmox_password and ssh_public_key"
echo "   3. Run: terraform init && terraform apply"

# Cleanup
rm -f "$CLOUD_IMAGE_FILE"