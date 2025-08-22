#!/bin/bash

# Script to create Ubuntu 24.04 template for Proxmox
# This script should be run on the Proxmox host

set -e

VMID=${1:-999}
VM_NAME="ubuntu-24.04-template"
ISO_PATH="/var/lib/vz/template/iso/ubuntu-24.04.1-live-server-amd64.iso"
STORAGE="pve-data"
MEMORY=2048
CORES=2
DISK_SIZE=20G

echo "Creating Ubuntu 24.04 template (VMID: $VMID)..."

# Create VM
qm create $VMID \
  --name $VM_NAME \
  --memory $MEMORY \
  --cores $CORES \
  --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-pci \
  --scsi0 $STORAGE:$DISK_SIZE,cache=writeback \
  --ide2 $STORAGE:cloudinit \
  --boot c --bootdisk scsi0 \
  --serial0 socket --vga serial0 \
  --agent enabled=1

echo "VM $VMID created successfully."

# Set cloud-init configuration
qm set $VMID --ciuser ubuntu
qm set $VMID --cipassword ubuntu
qm set $VMID --ipconfig0 ip=dhcp
qm set $VMID --nameserver 8.8.8.8

echo "Cloud-init configuration applied."

# Download and set Ubuntu 24.04 image
if [ ! -f "$ISO_PATH" ]; then
    echo "Downloading Ubuntu 24.04 ISO..."
    wget -O "$ISO_PATH" https://releases.ubuntu.com/24.04.1/ubuntu-24.04.1-live-server-amd64.iso
fi

# Import the disk
echo "Converting to template..."
qm template $VMID

echo "Template $VM_NAME created successfully with VMID $VMID"
echo "You can now clone this template to create new VMs."

# Show template info
qm config $VMID