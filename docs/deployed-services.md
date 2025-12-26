# Deployed Homelab Services

## Overview

This document tracks all services deployed in the homelab Kubernetes cluster.

## Service Summary

### Media Services (Namespace: `media`)

#### Immich - Photo Management
- **URL**: http://immich.homelab.local
- **Description**: Self-hosted Google Photos alternative
- **Node Placement**: AMD64 workers only
- **Components**:
  - immich-server (2283)
  - immich-machine-learning (3003)
  - PostgreSQL database (pgvecto-rs)
  - Redis cache
- **Storage**:
  - 100Gi library storage
  - 20Gi database storage
  - 10Gi ML model cache
- **Resources**: 4GB RAM, 2 CPU (server), 8GB RAM, 4 CPU (ML)

### Home Automation (Namespace: `home-automation`)

#### Home Assistant
- **URL**: http://homeassistant.homelab.local
- **Description**: Open-source home automation platform
- **Node Placement**: ARM64 Pi workers (preferred)
- **Features**:
  - Smart home control
  - Device integration
  - Automation engine
- **Storage**: 5Gi config storage
- **Resources**: 512Mi-2Gi RAM, 250m-1000m CPU
- **Network**: hostNetwork enabled for device discovery

### Productivity (Namespace: `productivity`)

#### Vaultwarden
- **URL**: http://vaultwarden.homelab.local
- **Description**: Lightweight Bitwarden server (password manager)
- **Node Placement**: AMD64 workers
- **Features**:
  - Password vault
  - 2FA support
  - WebSocket enabled
  - Signups allowed (can be disabled later)
- **Storage**: 10Gi data storage
- **Resources**: 256Mi-1Gi RAM, 100m-1000m CPU

### Infrastructure (Namespace: `infrastructure`)

#### Uptime Kuma
- **URL**: http://uptime.homelab.local
- **Description**: Self-hosted monitoring and status page
- **Node Placement**: ARM64 Pi workers (preferred)
- **Features**:
  - Service uptime monitoring
  - Status pages
  - Notifications
- **Storage**: 5Gi data storage
- **Resources**: 256Mi-512Mi RAM, 100m-500m CPU

## Monitoring Services (Namespace: `monitoring`)

### Grafana
- **URL**: http://grafana.homelab.local
- **Description**: Metrics visualization and dashboards

### Prometheus
- **URL**: http://prometheus.homelab.local
- **Description**: Metrics collection and storage

### AlertManager
- **URL**: http://alertmanager.homelab.local
- **Description**: Alert routing and management

### Traefik Dashboard
- **URL**: http://traefik.homelab.local
- **Description**: Ingress controller dashboard

---

## DNS Configuration

Add these entries to your DNS server (Pi-hole) or `/etc/hosts`:

```
10.1.1.100    immich.homelab.local
10.1.1.100    homeassistant.homelab.local
10.1.1.100    vaultwarden.homelab.local
10.1.1.100    uptime.homelab.local
10.1.1.100    grafana.homelab.local
10.1.1.100    prometheus.homelab.local
10.1.1.100    alertmanager.homelab.local
10.1.1.100    traefik.homelab.local
```

---

## Node Placement Strategy

### ARM64 Pi Workers (k8s-worker-pi-01, k8s-worker-pi-02)
- 3GB RAM, 2 CPU each
- **Running**:
  - Home Assistant
  - Uptime Kuma
- **Suitable for**:
  - IoT/Home automation services
  - Lightweight monitoring
  - MQTT brokers
  - Node-RED

### AMD64 Workers (k8s-worker-01 through k8s-worker-10)
- 8GB RAM, 4 CPU each
- **Running**:
  - Immich (photos + ML)
  - Vaultwarden
- **Suitable for**:
  - Heavy workloads
  - Databases
  - Media transcoding
  - ML/AI workloads

---

## Storage Architecture

### Current Setup
- **StorageClass**: local-path (default)
- **Provisioner**: Rancher local-path provisioner
- **Location**: Local node storage

### Future: TrueNAS NFS Integration (Planned)
1. Install TrueNAS on VM 2032 (10.1.1.201)
2. Create NFS shares for:
   - k8s-pvcs (general persistent volumes)
   - immich-data (photo library)
   - media (Plex/Jellyfin content)
   - backups (Velero backup storage)
3. Deploy NFS CSI driver
4. Migrate PVCs to NFS storage

---

## Access Instructions

### First-Time Setup

#### Immich
1. Navigate to http://immich.homelab.local
2. Create admin account
3. Configure mobile apps with server URL

#### Home Assistant
1. Navigate to http://homeassistant.homelab.local
2. Wait for initial setup (1-2 minutes)
3. Create owner account
4. Configure integrations

#### Vaultwarden
1. Navigate to http://vaultwarden.homelab.local
2. Create account
3. Configure Bitwarden browser extension/apps with server URL
4. **IMPORTANT**: Set `SIGNUPS_ALLOWED=false` after creating accounts

#### Uptime Kuma
1. Navigate to http://uptime.homelab.local
2. Create admin account
3. Add monitoring targets

---

## Useful Commands

### Check Service Status
```bash
# All application pods
kubectl get pods -n media
kubectl get pods -n home-automation
kubectl get pods -n productivity
kubectl get pods -n infrastructure

# All IngressRoutes
kubectl get ingressroute -A

# Storage usage
kubectl get pvc -A
```

### View Logs
```bash
# Immich
kubectl logs -n media -l app=immich-server
kubectl logs -n media -l app=immich-machine-learning

# Home Assistant
kubectl logs -n home-automation -l app=home-assistant

# Vaultwarden
kubectl logs -n productivity -l app=vaultwarden

# Uptime Kuma
kubectl logs -n infrastructure -l app=uptime-kuma
```

### Restart Services
```bash
kubectl rollout restart deployment -n media immich-server
kubectl rollout restart deployment -n home-automation home-assistant
kubectl rollout restart deployment -n productivity vaultwarden
kubectl rollout restart deployment -n infrastructure uptime-kuma
```

---

## Resource Usage

### Current Allocation
- **Media namespace**: ~6GB RAM (Immich + PostgreSQL + Redis)
- **Home Automation**: ~1GB RAM (Home Assistant)
- **Productivity**: ~512MB RAM (Vaultwarden)
- **Infrastructure**: ~512MB RAM (Uptime Kuma)
- **Monitoring**: ~4GB RAM (Prometheus, Grafana, Loki)
- **Total**: ~12GB RAM allocated across cluster

### Available Capacity
- **AMD64 Workers**: 10 nodes × 8GB = 80GB RAM
- **ARM64 Pi Workers**: 2 nodes × 3GB = 6GB RAM
- **Total Cluster**: 86GB RAM, plenty of room for expansion

---

## Future Service Recommendations

### Media Stack
- **Plex/Jellyfin**: Media server (AMD64, 4-8GB RAM)
- **Sonarr/Radarr**: TV/Movie automation (AMD64, 1-2GB RAM)
- **Prowlarr**: Indexer manager (AMD64, 512MB RAM)
- **Transmission**: Download client (AMD64, 512MB-1GB RAM)

### Productivity
- **Nextcloud**: File sync and collaboration (AMD64, 2-4GB RAM)
- **Paperless-NGX**: Document management (AMD64, 1-2GB RAM)
- **Bookstack**: Wiki/documentation (AMD64, 512MB-1GB RAM)

### Home Automation Additions
- **Mosquitto**: MQTT broker (ARM64, 128-256MB RAM)
- **Node-RED**: Automation flows (ARM64, 256-512MB RAM)
- **Zigbee2MQTT**: Zigbee bridge (ARM64, 256-512MB RAM)
- **ESPHome**: ESP device manager (ARM64, 256-512MB RAM)

### Development
- **Gitea**: Git hosting (AMD64, 512MB-1GB RAM)
- **Code Server**: VS Code in browser (AMD64, 1-2GB RAM)
