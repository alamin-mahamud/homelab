# Proxmox VE Documentation

Comprehensive guide for setting up and managing Proxmox Virtual Environment in your homelab.

## Quick Start Guides

- [Post-Installation Setup](./proxmox-post-installation.md) - Essential configuration after installing Proxmox
- [VM Templates](./proxmox-vm-template.md) - Creating and managing VM templates
- [Storage Expansion](./increase-storage.md) - Adding and managing storage pools

## Architecture Overview

Proxmox VE is an open-source server virtualization management platform that integrates:
- KVM hypervisor for virtual machines
- LXC for lightweight containers
- Software-defined storage and networking
- High availability clustering
- Built-in backup and restore

## Best Practices

### General Guidelines

- **Kernel Management**
  - Use enterprise kernels for production stability
  - Regular updates: `apt update && apt dist-upgrade`
  - Schedule maintenance windows for kernel updates

- **Subscription Management**
  - For production: Consider enterprise subscription
  - For homelab: Disable subscription pop-ups via configuration

### Cluster & High Availability

- **Node Configuration**
  - Maintain odd number of nodes (minimum 3) to prevent split-brain
  - Use low-latency network for corosync communication
  - Dedicated network for cluster traffic recommended

- **HA Best Practices**
  - Configure proper fencing mechanisms
  - Avoid running HA VMs on storage monitor nodes
  - Test failover scenarios regularly
  - Document recovery procedures

### Storage Configuration

#### ZFS Storage
- **Requirements**
  - ECC RAM strongly recommended
  - Minimum 1GB RAM per TB of storage
  - Avoid using swap on ZFS systems

- **Performance Optimization**
  - Keep utilization below 80%
  - Use appropriate RAID levels (RAIDZ1/2/3)
  - Enable compression and deduplication carefully
  - Regular scrubs and snapshots

#### Ceph Storage
- **Deployment Considerations**
  - Minimum 3 nodes for production
  - Dedicated 10GbE network for Ceph traffic
  - Separate journal/WAL devices on NVMe
  - Monitor placement on dedicated nodes

#### Storage Best Practices
- Never mix ZFS and Ceph on same OS disks
- Use local LVM only for ephemeral data
- Implement tiered storage strategy
- Regular backup verification

### Networking Architecture

- **Network Segmentation**
  - Management network (Proxmox GUI/SSH)
  - VM traffic network
  - Storage network (iSCSI/Ceph)
  - Backup network

- **Performance Optimization**
  - Bonded NICs with LACP or active-backup
  - Jumbo frames (MTU 9000) for storage networks
  - VLANs for traffic isolation
  - Consider Open vSwitch for advanced configurations

### Security Hardening

- **Access Control**
  - Enable Two-Factor Authentication (2FA)
  - Use realm-based authentication
  - Implement role-based access control (RBAC)
  - Regular audit of user permissions

- **Network Security**
  - Firewall rules at datacenter and node level
  - VPN or SSH bastion for remote access
  - API token rotation
  - Enable fail2ban for brute-force protection

- **Monitoring & Logging**
  - Centralized log collection
  - Security event monitoring
  - Regular security updates
  - Vulnerability scanning

### Backup & Disaster Recovery

- **Backup Strategy**
  - Deploy Proxmox Backup Server (PBS)
  - Follow 3-2-1 rule: 3 copies, 2 different media, 1 offsite
  - Automated backup schedules
  - Regular restore testing

- **Backup Configuration**
  - Dedicated backup storage pool
  - Compression and encryption
  - Retention policies
  - Bandwidth limiting for backups

### Automation & Infrastructure as Code

- **VM Provisioning**
  - Cloud-Init for automated configuration
  - Template-based deployments
  - Standardized naming conventions

- **Configuration Management**
  - Proxmox API integration
  - Ansible playbooks for automation
  - Terraform for infrastructure provisioning
  - GitOps for configuration tracking

- **Maintenance Automation**
  - Automated patching schedules
  - Live migration for zero-downtime updates
  - Health check scripts
  - Capacity planning automation

## Advanced Configurations

### Performance Tuning

- **CPU Optimization**
  - CPU pinning for performance-critical VMs
  - NUMA awareness
  - CPU governor settings
  - Host CPU type passthrough

- **Memory Management**
  - Ballooning configuration
  - KSM (Kernel Same-page Merging)
  - Huge pages for large memory VMs
  - Memory overcommitment strategies

- **Storage Performance**
  - I/O scheduler tuning
  - Cache settings optimization
  - Disk alignment
  - TRIM/discard support

### Monitoring & Observability

- **Metrics Collection**
  - Prometheus integration
  - InfluxDB for time-series data
  - Custom metric exporters

- **Visualization**
  - Grafana dashboards
  - Real-time performance monitoring
  - Capacity planning reports
  - Alert configuration

### Expansion & Scaling

- **Cluster Growth**
  - Adding nodes dynamically
  - Storage pool expansion
  - Network scaling considerations
  - License planning

- **Cloud-Like Features**
  - Self-service portals
  - API-driven provisioning
  - Multi-tenancy setup
  - Billing integration

- **Remote Management**
  - Tailscale/ZeroTier for secure access
  - IPMI/iDRAC integration
  - Remote console access
  - Out-of-band management

## Troubleshooting Guide

### Common Issues

- **Cluster Problems**
  - Quorum loss recovery
  - Node fence recovery
  - Corosync troubleshooting
  - Split-brain resolution

- **Storage Issues**
  - ZFS pool recovery
  - Ceph health problems
  - Disk replacement procedures
  - Performance degradation

- **Network Troubleshooting**
  - Bridge configuration issues
  - VLAN connectivity problems
  - MTU mismatches
  - DNS resolution failures

### Maintenance Procedures

- **Regular Tasks**
  - Update procedures
  - Certificate renewal
  - Log rotation
  - Backup verification

- **Emergency Procedures**
  - Disaster recovery steps
  - Data recovery methods
  - Cluster recovery
  - Backup restoration

## Resources

- [Official Proxmox Wiki](https://pve.proxmox.com/wiki/Main_Page)
- [Proxmox Forum](https://forum.proxmox.com/)
- [API Documentation](https://pve.proxmox.com/wiki/Proxmox_VE_API)
- [Community Scripts](https://github.com/tteck/Proxmox)