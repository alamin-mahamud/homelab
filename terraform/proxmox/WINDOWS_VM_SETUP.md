# 🖥️ Windows 11 Desktop VM with GPU Passthrough - Setup Complete!

## ✅ VM Creation Status

Your Windows 11 VM has been successfully created with GPU passthrough configuration!

### 📊 VM Specifications
- **VM ID**: 900
- **Name**: windows-11-desktop
- **Memory**: 16GB (16,384 MB)
- **CPU**: 4 cores (host CPU type)
- **Storage**: 50GB NVMe-style disk
- **GPU**: NVIDIA RTX 4080 SUPER (passthrough enabled)
- **Network**: Virtio with bridge vmbr0

### 🎮 GPU Passthrough Configuration
- ✅ **IOMMU**: Enabled and ready
- ✅ **GPU Device**: 01:00 (RTX 4080 SUPER + Audio)
- ✅ **VGA**: Disabled (GPU takes over display)
- ✅ **Machine Type**: Q35 (required for GPU passthrough)
- ✅ **BIOS**: OVMF/UEFI (required for modern GPUs)
- ✅ **TPM 2.0**: Enabled (Windows 11 requirement)

### 💾 VM 701 Resource Adjustment
- ✅ **Cores**: Reduced from 20 to 16 (freed 4 cores for Windows VM)
- ✅ **Memory**: Reduced from 96GB to 80GB (freed 16GB for Windows VM)

## 📥 Windows 11 ISO Download Required

**⚠️ Important**: You need to manually download the Windows 11 ISO due to Microsoft licensing restrictions.

### Method 1: Official Microsoft Download (Recommended)
1. Visit: https://www.microsoft.com/software-download/windows11
2. Click "Download Windows 11 Disk Image (ISO)"
3. Select "Windows 11 (multi-edition ISO)"
4. Choose your language
5. Download the 64-bit ISO file

### Method 2: Windows 11 Enterprise Evaluation (90 days)
1. Visit: https://www.microsoft.com/evalcenter/download-windows-11-enterprise
2. Fill out the form (can use any business info)
3. Download the evaluation ISO

### 📂 Save Location
Upload the downloaded ISO to your Proxmox server:
```bash
# On your local machine
scp Windows11.iso root@10.1.0.0:/var/lib/vz/template/iso/

# Or download directly on Proxmox
ssh root@10.1.0.0
cd /var/lib/vz/template/iso
# Upload your downloaded ISO here
```

## 🚀 Installation Steps

### 1. Attach Windows ISO
```bash
# Replace 'Windows11.iso' with your actual ISO filename
qm set 900 --ide0 local:iso/Windows11.iso,media=cdrom
```

### 2. Start the VM
```bash
qm start 900
```

### 3. Connect to VM Console
- **Proxmox Web UI**: Go to VM 900 → Console
- **VNC**: Use the VNC console in Proxmox web interface
- **Direct GPU**: If you have a monitor connected to the RTX 4080 SUPER

### 4. Windows Installation Process

#### 4.1 Boot from ISO
- VM will boot from the Windows 11 ISO
- Press any key when prompted to boot from CD/DVD

#### 4.2 Storage Driver Installation (Critical!)
**⚠️ Windows won't see the disk without VirtIO drivers:**

1. When you reach "Where do you want to install Windows?"
2. Click "Load driver"
3. Click "Browse" and navigate to the VirtIO ISO (D: or E: drive)
4. Go to `amd64\w11` (for Windows 11) or `amd64\w10` (for Windows 10)
5. Select `viostor.inf` and click OK
6. Install the driver
7. Your 50GB disk should now appear in the list

#### 4.3 Network Driver (Optional during installation)
1. Load driver again if you need network during installation
2. Navigate to `NetKVM\w11\amd64` on the VirtIO ISO
3. Install `netkvm.inf`

#### 4.4 Complete Windows Installation
1. Select your 50GB disk
2. Follow normal Windows 11 installation steps
3. Create user account
4. Complete initial setup

### 5. Post-Installation Configuration

#### 5.1 Install All VirtIO Drivers
1. Open Device Manager
2. Install remaining VirtIO drivers for any unknown devices
3. Or run the automated installer from VirtIO ISO: `virtio-win-gt-x64.msi`

#### 5.2 Install Proxmox Guest Agent
1. From VirtIO ISO, run: `guest-agent\qemu-ga-x86_64.msi`
2. This enables better VM management from Proxmox

#### 5.3 Install NVIDIA Drivers
1. Download latest NVIDIA drivers for RTX 4080 SUPER
2. Install normally - the GPU should be detected via passthrough
3. Restart after installation

#### 5.4 Enable GPU Hardware Acceleration
1. Right-click Desktop → Display Settings
2. Go to Advanced Display Settings
3. Verify GPU is detected and active
4. Enable hardware acceleration in Windows

## 🔧 Troubleshooting

### VM Won't Start
```bash
# Check VM status
qm status 900

# View VM logs
qm log 900

# Check GPU availability
lspci | grep VGA
```

### No Display Output
1. **Check GPU Connection**: Ensure monitor is connected to RTX 4080 SUPER, not motherboard
2. **Check VGA Setting**: Should be "none" - verify with `qm config 900`
3. **BIOS Settings**: Ensure primary GPU is set to PCIe in host BIOS

### Storage Not Detected
1. **VirtIO Drivers**: Must install during Windows installation
2. **SCSI Controller**: Should be `virtio-scsi-pci` - already configured

### Network Issues
1. Install VirtIO network drivers
2. Check bridge configuration: `ip link show vmbr0`

### GPU Not Detected in Windows
1. **Install NVIDIA Drivers**: Download latest from NVIDIA website
2. **Check Passthrough**: Verify with `lspci -k | grep -A 3 VGA`
3. **VFIO Binding**: GPU should be bound to vfio-pci driver on host

## 📊 Performance Optimization

### Windows Settings
- **Power Plan**: Set to "High Performance"
- **Visual Effects**: Adjust for performance
- **Windows Updates**: Keep current for driver compatibility

### VM Settings (Already Applied)
- ✅ **CPU**: Host type for best performance
- ✅ **Storage**: NVMe emulation with iothread
- ✅ **Memory**: Ballooning disabled
- ✅ **NUMA**: Enabled for better memory access

## 🎯 Final Verification

### Check GPU Passthrough Success
1. **Device Manager**: NVIDIA RTX 4080 SUPER should appear
2. **NVIDIA Control Panel**: Should open and show GPU details
3. **GPU-Z**: Should detect the full GPU with all features
4. **DirectX Diagnostic**: Should show the NVIDIA GPU

### Test Performance
1. **Windows Experience Index**: Should reflect high-performance GPU
2. **3DMark/Games**: Test with demanding applications
3. **GPU Monitoring**: Use MSI Afterburner or similar

## 📋 Current VM Configuration
```
VM ID: 900
Name: windows-11-desktop
Memory: 16GB
CPU: 4 cores (host type)
Storage: 50GB (pve-data)
GPU: RTX 4080 SUPER (01:00)
Network: virtio bridge
BIOS: OVMF (UEFI)
TPM: 2.0 enabled
VirtIO: Drivers available
```

## 🎉 Success!

Your Windows 11 VM with RTX 4080 SUPER GPU passthrough is ready! This setup provides near-native GPU performance for:

- 🎮 **Gaming**: Run Windows games with full GPU acceleration
- 🎨 **Content Creation**: Video editing, 3D rendering, streaming
- 💻 **Development**: GPU-accelerated development environments
- 🧪 **AI/ML**: CUDA workloads and machine learning

Just download the Windows 11 ISO and follow the installation steps above!