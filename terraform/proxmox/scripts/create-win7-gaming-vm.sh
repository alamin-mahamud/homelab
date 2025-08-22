#!/bin/bash

# Windows 7 Gaming VM for Command & Conquer Tiberian Sun
# Optimized for retro gaming with GPU passthrough

set -e

# Configuration
VMID=${1:-777}
VM_NAME="win7-retro-gaming"
MEMORY=8192   # 8GB is plenty for Windows 7 and retro games
CORES=4       # 4 cores is optimal for Windows 7
STORAGE="pve-data"
DISK_SIZE=100G  # 100GB for OS and games
BRIDGE="vmbr0"

echo "🎮 Creating Windows 7 Gaming VM for Command & Conquer (VMID: $VMID)..."

# Create the Windows 7 VM
echo "🏗️  Creating Windows 7 VM..."
qm create $VMID \
  --name "$VM_NAME" \
  --memory $MEMORY \
  --cores $CORES \
  --sockets 1 \
  --cpu host \
  --net0 e1000,bridge=$BRIDGE \
  --scsihw virtio-scsi-pci \
  --scsi0 $STORAGE:$DISK_SIZE,cache=writeback,discard=on \
  --machine pc-i440fx-9.2 \
  --bios seabios \
  --agent enabled=1,fstrim_cloned_disks=1 \
  --boot order=scsi0 \
  --ostype win7

# Note: Using e1000 network instead of virtio for better Windows 7 compatibility
# Using pc-i440fx machine type for better legacy compatibility

# Configure GPU passthrough for RTX 4080 SUPER
echo "🎮 Configuring GPU passthrough..."
qm set $VMID --hostpci0 01:00,pcie=1,x-vga=1

# Set VGA to none since GPU will handle display
qm set $VMID --vga none

# Add Windows 7 ISO
echo "💿 Attaching Windows 7 ISO..."
qm set $VMID --ide0 shared-iso:iso/Windows_7.iso,media=cdrom

# Add VirtIO drivers ISO
echo "🔧 Attaching VirtIO drivers ISO..."
if [ -f "/var/lib/vz/template/iso/virtio-win.iso" ]; then
    qm set $VMID --ide1 local:iso/virtio-win.iso,media=cdrom
else
    echo "⚠️  VirtIO drivers not found - will use standard drivers"
fi

# Windows 7 specific optimizations
echo "⚡ Applying Windows 7 gaming optimizations..."
qm set $VMID --cpu host,flags=+pcid
qm set $VMID --numa 0  # Disable NUMA for better compatibility
qm set $VMID --balloon 0  # Disable ballooning for consistent performance

# Add USB passthrough for game controllers
echo "🎮 Adding USB support for game controllers..."
qm set $VMID --usb0 host=spice

# Add audio device for game sound
echo "🔊 Adding audio device..."
qm set $VMID --audio0 device=ich9-intel-hda,driver=spice

echo ""
echo "✅ Windows 7 Gaming VM created successfully!"
echo ""
echo "📋 VM Configuration:"
qm config $VMID
echo ""
echo "🚀 Installation Steps:"
echo "1. Start VM: qm start $VMID"
echo "2. Connect via Proxmox console or monitor connected to GPU"
echo "3. Install Windows 7"
echo "4. Install chipset and storage drivers from VirtIO ISO (optional)"
echo "5. Install NVIDIA drivers (use older version compatible with Win7)"
echo "6. Install DirectX 9.0c for Tiberian Sun"
echo ""
echo "🎮 Command & Conquer Tiberian Sun Setup:"
echo "1. Download from: https://www.ea.com/games/command-and-conquer/command-and-conquer-remastered"
echo "   Or get the freeware version"
echo "2. Install game"
echo "3. Apply Windows XP SP3 compatibility mode if needed"
echo "4. Run as Administrator"
echo "5. Consider installing CnCNet for multiplayer support"
echo ""
echo "💡 Gaming Tips:"
echo "   - Disable Windows Aero for better performance"
echo "   - Set Windows to 'Best Performance' mode"
echo "   - Disable unnecessary visual effects"
echo "   - Install DirectX 9.0c redistributables"
echo "   - For Tiberian Sun: Enable compatibility mode for Windows XP SP3"
echo ""
echo "🎯 GPU Info:"
echo "   GPU: NVIDIA RTX 4080 SUPER"
echo "   Note: Use NVIDIA driver version 474.44 or earlier for Win7 support"
echo "   Download: https://www.nvidia.com/drivers/beta"
echo ""
echo "⚠️  Important Notes:"
echo "   - Windows 7 is EOL - use offline or with caution"
echo "   - Some modern GPU features may be limited"
echo "   - Perfect for retro gaming like C&C Tiberian Sun!"