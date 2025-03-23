- [First 11 Things](https://technotim.live/posts/first-11-things-proxmox/)

# Network Interface Configuration

```
auto lo
iface lo inet loopback

iface eno1 inet manual

auto vmbr0
iface vmbr0 inet static
        address 10.1.0.0/8 # Management IP (Proxmox UI)
        gateway 10.0.0.1   # Gateway for management VLAN
        bridge-ports eno1  # Physical NIC
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
        bridge-vids 10,20,30,40 # Allowed VLANs, 10-management, 20-general-vm-traffic, 30-storage, 40-IoT

iface wlp11s0 inet manual

source /etc/network/interfaces.d/*
```
