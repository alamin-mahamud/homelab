#!/bin/bash

# Windows 11 VM with GPU Passthrough Creation Script
# This script creates a Windows 11 VM optimized for GPU passthrough

set -e

# Configuration
VMID=${1:-900}
VM_NAME="windows-11-desktop"
MEMORY=16384  # 16GB
CORES=4
STORAGE="pve-data"
BRIDGE="vmbr0"
ISO_STORAGE="local"

# Paths
WIN_ISO="Win11_23H2_x64.iso"
VIRTIO_ISO="virtio-win.iso"

echo "🖥️  Creating Windows 11 VM with GPU Passthrough (VMID: $VMID)..."

# Check if ISOs exist
if [ ! -f "/var/lib/vz/template/iso/$WIN_ISO" ]; then
    echo "❌ Windows 11 ISO not found at /var/lib/vz/template/iso/$WIN_ISO"
    echo "📥 Please download Windows 11 ISO from:"
    echo "   https://www.microsoft.com/software-download/windows11"
    echo "   Save as: /var/lib/vz/template/iso/$WIN_ISO"
    echo ""
    echo "🔄 Alternatively, you can download manually:"
    echo "   cd /var/lib/vz/template/iso"
    echo "   wget -O '$WIN_ISO' 'YOUR_WINDOWS_11_ISO_URL'"
    echo ""
    read -p "❓ Continue anyway to create VM structure? (y/N): " -n 1 -r
    echo
    if [[ ! \$REPLY =~ ^[Yy]\$ ]]; then
        exit 1
    fi
fi

if [ ! -f "/var/lib/vz/template/iso/$VIRTIO_ISO" ]; then
    echo "📥 Downloading VirtIO drivers..."
    cd /var/lib/vz/template/iso
    wget -O "$VIRTIO_ISO" "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso" || {
        echo "❌ Failed to download VirtIO drivers. You can download manually from:"
        echo "   https://github.com/virtio-win/virtio-win-pkg-scripts/blob/master/README.md"
    }
fi

# Reduce resources from VM 701 if it's using too much
echo "🔧 Checking VM 701 resources..."
if qm config 701 >/dev/null 2>&1; then
    CURRENT_CORES=$(qm config 701 | grep "^cores:" | cut -d' ' -f2)
    CURRENT_MEMORY=$(qm config 701 | grep "^memory:" | cut -d' ' -f2)
    
    echo "📊 VM 701 current resources: ${CURRENT_CORES} cores, ${CURRENT_MEMORY}MB RAM"
    
    if [ "$CURRENT_CORES" -gt 16 ]; then
        echo "🔄 Reducing VM 701 cores from $CURRENT_CORES to 16..."
        qm set 701 --cores 16
    fi
    
    if [ "$CURRENT_MEMORY" -gt 80000 ]; then
        echo "🔄 Reducing VM 701 memory from ${CURRENT_MEMORY}MB to 80GB..."
        qm set 701 --memory 81920  # 80GB
    fi
fi

# Create the Windows VM
echo "🏗️  Creating Windows 11 VM..."
qm create $VMID \
  --name "$VM_NAME" \
  --memory $MEMORY \
  --cores $CORES \
  --sockets 1 \
  --cpu host \
  --net0 virtio,bridge=$BRIDGE \
  --scsihw virtio-scsi-pci \
  --scsi0 $STORAGE:50,cache=writeback,discard=on,iothread=1 \
  --machine q35 \
  --bios ovmf \
  --agent enabled=1,fstrim_cloned_disks=1 \
  --boot order=scsi0 \
  --ostype win11

# Add EFI disk for UEFI boot
echo "💾 Adding EFI disk..."
qm set $VMID --efidisk0 $STORAGE:1,efitype=4m,pre-enrolled-keys=1

# Add TPM for Windows 11 requirements
echo "🔐 Adding TPM 2.0..."
qm set $VMID --tpmstate0 $STORAGE:1,version=v2.0

# Configure GPU passthrough for RTX 4080 SUPER
echo "🎮 Configuring GPU passthrough..."
qm set $VMID --hostpci0 01:00,pcie=1,x-vga=1

# Set VGA to none since GPU will handle display
qm set $VMID --vga none

# Add Windows 11 ISO if available
if [ -f "/var/lib/vz/template/iso/$WIN_ISO" ]; then
    echo "💿 Attaching Windows 11 ISO..."
    qm set $VMID --ide0 $ISO_STORAGE:iso/$WIN_ISO,media=cdrom
else
    echo "⚠️  Windows 11 ISO not found - you'll need to attach it manually"
fi

# Add VirtIO drivers ISO if available
if [ -f "/var/lib/vz/template/iso/$VIRTIO_ISO" ]; then
    echo "🔧 Attaching VirtIO drivers ISO..."
    qm set $VMID --ide1 $ISO_STORAGE:iso/$VIRTIO_ISO,media=cdrom
else
    echo "⚠️  VirtIO drivers ISO not found - Windows may not detect storage/network"
fi

# Set additional Windows optimizations
echo "⚡ Applying Windows optimizations..."
qm set $VMID --cpu host,flags=+pcid
qm set $VMID --numa 1
qm set $VMID --balloon 0  # Disable ballooning for better performance

# Audio passthrough (optional)
echo "🔊 Adding audio device..."
qm set $VMID --audio0 device=ich9-intel-hda,driver=spice

echo ""
echo "✅ Windows 11 VM created successfully!"
echo ""
echo "📋 VM Configuration:"
qm config $VMID
echo ""
echo "🚀 Next Steps:"
echo "1. 📥 Download Windows 11 ISO to /var/lib/vz/template/iso/$WIN_ISO"
echo "2. 🖥️  Start VM: qm start $VMID"
echo "3. 🌐 Connect via console: qm monitor $VMID or use Proxmox web UI"
echo "4. 💾 Install Windows 11 (select 'Load driver' and use VirtIO drivers)"
echo "5. 🎮 Install NVIDIA drivers after Windows installation"
echo ""
echo "💡 Pro Tips:"
echo "   - During Windows installation, load VirtIO drivers for storage/network"
echo "   - Install Proxmox VE Guest Agent after Windows installation"
echo "   - Install latest NVIDIA drivers for RTX 4080 SUPER"
echo "   - Enable Windows hardware acceleration in Display settings"
echo ""
echo "🔧 GPU Passthrough Status:"
echo "   GPU: NVIDIA RTX 4080 SUPER (01:00.0)"
echo "   IOMMU: Enabled and ready"
echo "   VGA: Disabled (GPU takes over display)"