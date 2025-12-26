#!/bin/bash

# Setup Raspberry Pi for Lightweight Services
# This script configures the Raspberry Pi node to run lightweight services

set -e

PI_HOST="10.1.0.1"
PI_USER="root"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

log "Starting Raspberry Pi configuration for lightweight services"

# Create docker-compose file for Pi services
cat > /tmp/pi-docker-compose.yml <<'EOF'
version: '3.8'

services:
  # DNS Server - Pi-hole
  pihole:
    container_name: pihole
    image: pihole/pihole:latest
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "67:67/udp"
      - "8080:80/tcp"
    environment:
      TZ: 'UTC'
      WEBPASSWORD: 'admin123'
      DNSSEC: 'true'
      PIHOLE_DNS_: '8.8.8.8;8.8.4.4'
    volumes:
      - ./pihole/etc-pihole:/etc/pihole
      - ./pihole/etc-dnsmasq.d:/etc/dnsmasq.d
    cap_add:
      - NET_ADMIN
    restart: unless-stopped

  # Monitoring - Node Exporter
  node-exporter:
    container_name: node_exporter
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    restart: unless-stopped

  # MQTT Broker for IoT
  mosquitto:
    container_name: mosquitto
    image: eclipse-mosquitto:latest
    ports:
      - "1883:1883"
      - "9001:9001"
    volumes:
      - ./mosquitto/config:/mosquitto/config
      - ./mosquitto/data:/mosquitto/data
      - ./mosquitto/log:/mosquitto/log
    restart: unless-stopped

  # Zigbee2MQTT for smart home devices
  zigbee2mqtt:
    container_name: zigbee2mqtt
    image: koenkk/zigbee2mqtt:latest
    ports:
      - "8081:8080"
    volumes:
      - ./zigbee2mqtt/data:/app/data
      - /run/udev:/run/udev:ro
    devices:
      - /dev/ttyACM0:/dev/ttyACM0
    environment:
      TZ: UTC
    restart: unless-stopped
    depends_on:
      - mosquitto

  # WireGuard VPN
  wireguard:
    container_name: wireguard
    image: linuxserver/wireguard:latest
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      PUID: 1000
      PGID: 1000
      TZ: UTC
      SERVERURL: homelab.local
      SERVERPORT: 51820
      PEERS: 5
      PEERDNS: auto
      INTERNAL_SUBNET: 10.13.13.0
    volumes:
      - ./wireguard/config:/config
      - /lib/modules:/lib/modules
    ports:
      - "51820:51820/udp"
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    restart: unless-stopped

  # Nginx Proxy Manager
  nginx-proxy-manager:
    container_name: nginx-proxy-manager
    image: 'jc21/nginx-proxy-manager:latest'
    ports:
      - '80:80'
      - '443:443'
      - '81:81'
    volumes:
      - ./nginx/data:/data
      - ./nginx/letsencrypt:/etc/letsencrypt
    restart: unless-stopped

  # Heimdall Dashboard
  heimdall:
    container_name: heimdall
    image: linuxserver/heimdall:latest
    environment:
      PUID: 1000
      PGID: 1000
      TZ: UTC
    volumes:
      - ./heimdall/config:/config
    ports:
      - "8082:80"
    restart: unless-stopped

  # Uptime Kuma for monitoring
  uptime-kuma:
    container_name: uptime-kuma
    image: louislam/uptime-kuma:latest
    ports:
      - "3001:3001"
    volumes:
      - ./uptime-kuma/data:/app/data
    restart: unless-stopped
EOF

# Create Mosquitto configuration
cat > /tmp/mosquitto.conf <<'EOF'
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log

listener 1883
allow_anonymous true

listener 9001
protocol websockets
EOF

# Deploy to Raspberry Pi
log "Copying configuration files to Raspberry Pi..."
ssh $PI_USER@$PI_HOST "mkdir -p /opt/homelab-services/{pihole,mosquitto/config,zigbee2mqtt,wireguard,nginx,heimdall,uptime-kuma}"
scp /tmp/pi-docker-compose.yml $PI_USER@$PI_HOST:/opt/homelab-services/docker-compose.yml
scp /tmp/mosquitto.conf $PI_USER@$PI_HOST:/opt/homelab-services/mosquitto/config/mosquitto.conf

# Install Docker if not present
log "Ensuring Docker is installed on Raspberry Pi..."
ssh $PI_USER@$PI_HOST << 'ENDSSH'
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker root
    systemctl enable docker
    systemctl start docker
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    apt-get update
    apt-get install -y docker-compose
fi
ENDSSH

# Start services
log "Starting services on Raspberry Pi..."
ssh $PI_USER@$PI_HOST << 'ENDSSH'
cd /opt/homelab-services
docker-compose down || true
docker-compose up -d

# Wait for services to start
sleep 10

# Show status
docker-compose ps
ENDSSH

# Configure Pi-hole as primary DNS
log "Configuring Pi-hole settings..."
ssh $PI_USER@$PI_HOST << 'ENDSSH'
# Add custom DNS records for homelab services
cat > /opt/homelab-services/pihole/etc-dnsmasq.d/02-homelab.conf <<'DNSEOF'
# Homelab DNS records
address=/grafana.homelab.local/10.2.0.101
address=/prometheus.homelab.local/10.2.0.102
address=/plex.homelab.local/10.2.0.103
address=/nextcloud.homelab.local/10.2.0.104
address=/homeassistant.homelab.local/10.2.0.105
address=/portainer.homelab.local/10.2.0.106
address=/pihole.homelab.local/10.1.0.1
address=/dashboard.homelab.local/10.1.0.1
DNSEOF

# Restart Pi-hole to apply changes
docker restart pihole
ENDSSH

# Setup monitoring for the Pi
log "Configuring monitoring integration..."
cat > /tmp/pi-monitoring.yaml <<'EOF'
apiVersion: v1
kind: Endpoints
metadata:
  name: raspberry-pi-metrics
  namespace: monitoring
subsets:
  - addresses:
      - ip: 10.1.0.1
    ports:
      - name: metrics
        port: 9100
        protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: raspberry-pi-metrics
  namespace: monitoring
  labels:
    app: raspberry-pi
spec:
  type: ClusterIP
  clusterIP: None
  ports:
    - name: metrics
      port: 9100
      targetPort: 9100
---
apiVersion: v1
kind: ServiceMonitor
metadata:
  name: raspberry-pi
  namespace: monitoring
spec:
  endpoints:
    - port: metrics
      interval: 30s
  selector:
    matchLabels:
      app: raspberry-pi
EOF

# Apply monitoring configuration to K8s cluster (if kubectl is configured)
if kubectl cluster-info &>/dev/null; then
    log "Adding Raspberry Pi to Kubernetes monitoring..."
    kubectl apply -f /tmp/pi-monitoring.yaml
fi

# Create service status script
cat > /tmp/check-pi-services.sh <<'EOF'
#!/bin/bash
echo "=== Raspberry Pi Services Status ==="
echo ""
ssh root@10.1.0.1 'cd /opt/homelab-services && docker-compose ps'
echo ""
echo "=== Service URLs ==="
echo "Pi-hole Admin: http://10.1.0.1:8080/admin (password: admin123)"
echo "Heimdall Dashboard: http://10.1.0.1:8082"
echo "Uptime Kuma: http://10.1.0.1:3001"
echo "Nginx Proxy Manager: http://10.1.0.1:81"
echo "Zigbee2MQTT: http://10.1.0.1:8081"
echo ""
echo "=== DNS Server ==="
echo "Primary DNS: 10.1.0.1"
echo "Secondary DNS: 8.8.8.8"
EOF

chmod +x /tmp/check-pi-services.sh
cp /tmp/check-pi-services.sh /home/ubuntu/src/homelab/deployment/

log "✅ Raspberry Pi configuration completed!"
echo ""
echo "📋 Services running on Raspberry Pi:"
echo "===================================="
echo "• Pi-hole DNS (Port 53, Web: 8080)"
echo "• Node Exporter (Port 9100)"
echo "• Mosquitto MQTT (Port 1883)"
echo "• Zigbee2MQTT (Port 8081)"
echo "• WireGuard VPN (Port 51820)"
echo "• Nginx Proxy Manager (Port 81)"
echo "• Heimdall Dashboard (Port 8082)"
echo "• Uptime Kuma (Port 3001)"
echo ""
echo "Run './check-pi-services.sh' to check service status"

log "Raspberry Pi is now configured for lightweight services!"