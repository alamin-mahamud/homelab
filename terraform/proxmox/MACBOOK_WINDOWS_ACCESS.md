# 🖥️ Accessing Windows 7 VM from MacBook Pro

## Method 1: Proxmox Web Console (Easiest - Working Now!)

### Steps:
1. **Open Safari/Chrome on your MacBook**
2. **Navigate to**: https://10.1.0.0:8006
3. **Login** with your Proxmox credentials
4. **Navigate to**: Datacenter → pve → 777 (win7-retro-gaming)
5. **Click "Console"** button in the top menu
6. **Choose "noVNC"** (HTML5 console)

✅ **This is working right now!** Your VM is running with virtual display.

## Method 2: VNC Client (Better Performance)

### Install VNC Viewer on Mac:
```bash
# Install TigerVNC or RealVNC
brew install tigervnc-viewer
# OR download RealVNC from: https://www.realvnc.com/download/viewer/
```

### Configure VNC on Proxmox:
```bash
# First, check VNC port
ssh root@10.1.0.0 "qm config 777 | grep vnc"

# If no VNC, add it:
ssh root@10.1.0.0 "qm set 777 --vnc 0.0.0.0:5900,password"

# Set VNC password
ssh root@10.1.0.0 "qm set 777 --vncpassword yourpassword"
```

### Connect from Mac:
1. Open VNC Viewer
2. Connect to: `10.1.0.0:5900`
3. Enter password when prompted

## Method 3: SPICE Client (Best for Gaming)

### Install on Mac:
```bash
# Install virt-viewer (includes SPICE client)
brew install virt-viewer

# OR download RemoteViewer
brew install --cask remote-viewer
```

### Configure SPICE:
```bash
ssh root@10.1.0.0 "qm set 777 --vga qxl --spice host=0.0.0.0,port=5900,password=yourpassword"
```

### Connect:
```bash
remote-viewer spice://10.1.0.0:5900
```

## Method 4: RDP (After Windows Installation)

Once Windows 7 is installed:

### Enable RDP in Windows:
1. Right-click "Computer" → Properties
2. Click "Remote settings"
3. Select "Allow connections from computers..."
4. Click OK

### Connect from Mac:
1. **Install Microsoft Remote Desktop** from Mac App Store (free)
2. Click "+" → Add PC
3. PC name: `<Windows_VM_IP>`
4. User account: Your Windows username/password
5. Connect!

### Get Windows VM IP:
```bash
ssh root@10.1.0.0 "qm guest cmd 777 network-get-interfaces" | grep ip-address
```

## Method 5: Dual Display Setup (GPU + Virtual)

For gaming with GPU but remote access too:

```bash
# Stop VM
ssh root@10.1.0.0 "qm stop 777"

# Add both GPU and virtual display
ssh root@10.1.0.0 "qm set 777 --vga std --hostpci0 01:00,pcie=1"

# Start VM
ssh root@10.1.0.0 "qm start 777"
```

This gives you:
- Physical GPU for gaming performance
- Virtual display for remote access
- Switch between them in Windows display settings

## Current Status & Recommendations

### ✅ Right Now:
- VM is running with **QXL virtual display**
- Access via **Proxmox Web Console** immediately
- Perfect for Windows installation

### 🎮 For Gaming Later:
After Windows is installed and you want GPU performance:
```bash
# Re-enable GPU passthrough
ssh root@10.1.0.0 "qm stop 777"
ssh root@10.1.0.0 "qm set 777 --vga none --hostpci0 01:00,pcie=1,x-vga=1"
ssh root@10.1.0.0 "qm start 777"
```

Then use RDP for remote access while GPU handles the actual display.

## Quick Access Script

Save this as `connect-win7.sh`:
```bash
#!/bin/bash
echo "🖥️ Windows 7 VM Connection Options:"
echo ""
echo "1. Web Console:"
echo "   https://10.1.0.0:8006"
echo "   → VM 777 → Console"
echo ""
echo "2. Get VM IP for RDP:"
ssh root@10.1.0.0 "qm guest exec 777 'ipconfig' | grep -A 5 'IPv4'"
echo ""
echo "3. VM Status:"
ssh root@10.1.0.0 "qm status 777"
```

## Optimal Setup for Your Use Case

### For Installing Windows & General Use:
- **Use current setup** (QXL virtual display)
- Access via Proxmox web console
- Good enough for installation and setup

### For Playing Tiberian Sun:
- **Option A**: Keep virtual display (game is old, doesn't need GPU)
- **Option B**: Enable GPU passthrough + use RDP
- **Option C**: Use Steam Link or Parsec for game streaming

## Game Streaming Options

### Parsec (Recommended for Gaming):
1. Install Parsec on Windows 7 VM
2. Install Parsec on your MacBook
3. Stream games with low latency
4. Works great even with GPU passthrough

### Steam Link:
1. Install Steam on Windows 7
2. Install Steam Link on MacBook
3. Stream any game (not just Steam games)

## 🎯 Recommended Approach

**For Tiberian Sun specifically:**
1. **Keep current virtual display setup** (QXL)
2. **Use Proxmox web console** to install Windows
3. **Install the game**
4. **Play via web console** - Tiberian Sun doesn't need GPU power!

The game is from 1999 and runs fine on virtual graphics. You can always enable GPU passthrough later for more demanding games.

## Access Windows Right Now!

1. **Open your browser**
2. **Go to**: https://10.1.0.0:8006
3. **Login** to Proxmox
4. **Click VM 777**
5. **Click Console**
6. **Start installing Windows 7!**

Your VM is running and ready for access! 🎮