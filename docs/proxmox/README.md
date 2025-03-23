## Best Practices

### General

- Always use enterprise kernels
- Disable subscription pop-ups via config (for non-enterprise usage)
- Keep systems updated with apt update && apt dist-upgrade

### Cluster & HA

- Maintain odd number of nodes to avoid split brain (at least 3)
- Use corosync multicast or unicast with low latency
- Enable HA for critical VMs, configure fencing correctly
- Avoid running HA VMs on PBS or Ceph monitor nodes

### Storage
- Use ZFS or Ceph — never mix both on same OS disks

If using ZFS:
- ECC RAM mandatory
- Avoid using swap
- Keep 70–80% max utilization
- Avoid local LVM unless it's for ephemeral data or scratch


### Networking

- Bonded NICs with LACP or failover modes
- Separate storage, management and VM Traffic
- Jumbo Frames (MTU 9000) for Ceph & backup networks

### Security

- Use 2FA on GUI Logins
- Lock down API Access
- Use VPN & SSH bastion hosts for remote access
- Enable `fail2ban` and logs monitoring


### Backup & DR

- Use Proxmox Backup Server, store to dedicated ZFS pool
- Follow 3-2-1 rule: 3 copies, 2 different media, 1 offsite

### Automation

- Use Cloud-Init for VM templating
- Setup Proxmox API + Ansible/Terraform for repeatable infra
- Automate patching and reboots using cron + live migration (when needed)

)

### 🧭 Expansion & Cloud-Like Experience

- Add Proxmox VE + Ceph nodes dynamically
- Integrate with OpenNebula or Harvester for cloud portal feel
- Use Tailscale or ZeroTier to securely manage remote cluster


## Quick Ref
- [](./proxmox-vm-template.md)
- [](./proxmox-post-installation.md)
