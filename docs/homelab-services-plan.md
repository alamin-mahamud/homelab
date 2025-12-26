# Homelab Services Deployment Plan

## Node Architecture Strategy

### ARM64 Pi Workers (10.1.1.60-61) - 3GB RAM, 2 CPU
**Best for:**
- Lightweight monitoring/utility services
- IoT/Home automation services
- Low-resource daemons
- Pi-hole (DNS/Ad blocking)
- Mosquitto MQTT broker
- Node-RED
- ESPHome
- Zigbee2MQTT

### AMD64 Workers (10.1.1.31-40) - 8GB RAM, 4 CPU
**Best for:**
- Heavy workloads (Immich, Plex, Nextcloud)
- Databases (PostgreSQL, Redis)
- Media transcoding
- AI/ML workloads
- Storage-intensive applications

---

## Services to Deploy

### Category 1: Media Management (AMD64)
- **Immich** - Google Photos alternative (photo/video management)
- **Plex/Jellyfin** - Media server
- **Sonarr/Radarr** - TV/Movie automation
- **Prowlarr** - Indexer manager
- **Transmission/qBittorrent** - Download client

### Category 2: Home Automation (ARM64 - Pi Workers)
- **Home Assistant** - Smart home hub
- **Mosquitto** - MQTT broker
- **Node-RED** - Automation flows
- **ESPHome** - ESP device management
- **Zigbee2MQTT** - Zigbee bridge

### Category 3: Productivity (AMD64)
- **Nextcloud** - File sync and collaboration
- **Paperless-NGX** - Document management
- **Vaultwarden** - Password manager (Bitwarden)
- **Bookstack** - Documentation wiki
- **Linkding** - Bookmark manager

### Category 4: Infrastructure (AMD64)
- **Pi-hole** (can run on ARM64 too)
- **Uptime Kuma** - Status monitoring
- **Portainer** - Container management UI
- **Heimdall/Homer** - Dashboard
- **Nginx Proxy Manager** (optional, since we have Traefik)

### Category 5: Development (AMD64)
- **Gitea** - Git hosting
- **Drone CI** - CI/CD pipeline
- **Code Server** - VS Code in browser
- **Minio** - S3-compatible object storage

---

## Deployment Priority

### Phase 1: Storage Foundation
1. Install TrueNAS on VM 2032
2. Deploy NFS CSI driver in K8s
3. Create StorageClasses

### Phase 2: Core Services (This session)
1. **Immich** - Photo management (AMD64)
2. **Home Assistant** - Smart home (ARM64 - Pi)
3. **Vaultwarden** - Password manager (AMD64)
4. **Uptime Kuma** - Monitoring (can be ARM64)

### Phase 3: Media Services
1. Plex/Jellyfin
2. Sonarr/Radarr/Prowlarr
3. Transmission

### Phase 4: Productivity
1. Nextcloud
2. Paperless-NGX
3. Bookstack

---

## Resource Allocation Strategy

### Immich (AMD64)
- **Placement**: AMD64 workers only
- **Resources**: 2-4GB RAM, 2 CPU
- **Storage**: NFS for photos, local for ML models
- **Replicas**: 1
- **Node selector**: `kubernetes.io/arch: amd64`

### Home Assistant (ARM64)
- **Placement**: Pi workers preferred
- **Resources**: 512MB-1GB RAM, 1 CPU
- **Storage**: NFS for config
- **Replicas**: 1
- **Node selector**: `kubernetes.io/arch: arm64`

### Lightweight Services (ARM64)
- **Mosquitto, Node-RED, Zigbee2MQTT**: Pi workers
- **Resources**: 256-512MB RAM each
- **Node selector**: `kubernetes.io/arch: arm64`

### Heavy Services (AMD64)
- **Nextcloud, Plex, databases**: AMD64 workers only
- **Resources**: 2-8GB RAM depending on service
- **Node selector**: `kubernetes.io/arch: amd64`
