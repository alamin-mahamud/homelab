# Solving Storage Sharing with NAS

## Two DataSets in NAS

- Backup
  - VM and Container backup files ( VZDump backup file )
  - Proxmox and TrueNAS Configuration backups
  - Periodic snapshots and long-term archival data
- Shared:
  - Installation ISOs and VM/Container Templates (ISOs, Templates)
  - Non-performance critical VM Disk Images ( Disk Image, Container )
  - Shared App data, media files and documents ( Snippets, Import )

## Local Node Storage

- Performance Critical VM Disks
- Caching Layers
- Ephermeral Data
