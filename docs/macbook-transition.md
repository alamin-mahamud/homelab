# MacBook Transition & Remote Development Strategy

## Current Situation

### Retiring Hardware
- **MacBook Pro 2019 (15")**: Thermal throttling, battery degradation
- **MacBook Pro 2020 (13")**: Limited RAM, poor performance under load

### New Hardware
- **MacBook Air M4 2025**: 24GB RAM, 15" display (office-provided)

## Transition Strategy

### Phase 1: Remote Development Setup (Immediate)

#### On MacBook Air M4

1. **Development Environment**
```bash
# Essential tools
brew install tmux neovim git lazygit
brew install kubectl helm k9s
brew install terraform ansible
brew install tailscale wireguard-tools

# Container tools (limited local use)
brew install orbstack  # Better than Docker Desktop for M4
brew install lima      # Linux VMs on macOS
```

2. **VS Code Remote Setup**
```bash
# Install VS Code
brew install --cask visual-studio-code

# Essential extensions
code --install-extension ms-vscode-remote.remote-ssh
code --install-extension ms-vscode-remote.remote-containers
code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
```

3. **SSH Configuration**
```bash
# ~/.ssh/config
Host homelab
    HostName your-dedicated-ip
    User root
    Port 22
    ForwardAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host homelab-tunnel
    HostName homelab
    ProxyCommand ssh -W %h:%p jump-server
    
Host *.local
    ProxyJump homelab
```

### Phase 2: Homelab as Development Backend

#### Architecture
```
MacBook Air M4 (Client)
    ↓ (SSH/VS Code Remote)
Proxmox Cluster (Backend)
    → Dev VM (32GB RAM, 8 vCPU)
    → Build VM (64GB RAM, 16 vCPU)  
    → K8s Cluster (Production)
```

#### Development VM Setup
```bash
# Create dedicated dev VM on Proxmox
qm create 900 \
  --name dev-vm \
  --memory 32768 \
  --cores 8 \
  --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-pci \
  --scsi0 local-zfs:100

# Install development tools
apt update && apt install -y \
  build-essential git cmake \
  docker.io docker-compose \
  nodejs npm golang rustc \
  python3-pip python3-venv
```

### Phase 3: Travel Setup

#### Portable Development Options

1. **Short Trips (< 1 week)**
   - MacBook Air + Tailscale to homelab
   - Use VS Code Remote SSH
   - Latency tolerant work only

2. **Medium Trips (1-4 weeks)**
   - MacBook Air + Mini-PC in luggage
   - Local Proxmox + K3s on mini-PC
   - Sync with homelab via rsync/restic

3. **Long Trips (> 1 month)**
   - Ship mini-PC ahead to destination
   - Or use cloud resources (Hetzner/OVH)
   - Maintain VPN to homelab for data

#### Mini-PC Travel Configuration
```yaml
# Recommended Setup for GMKtec/Minisforum
OS: Proxmox VE 8.x
VMs:
  - Control: 2 vCPU, 4GB RAM (K3s master)
  - Worker: 4 vCPU, 16GB RAM (K3s worker)
  - Dev: 8 vCPU, 32GB RAM (Development)
  - Storage: TrueNAS Core VM for local NAS
```

### Phase 4: Old MacBook Repurposing

#### Option 1: Dedicated Build Servers
```bash
# Convert to Linux
# Install Ubuntu Server 24.04 LTS
# Use as GitHub Actions runners

# 2019 MBP → GPU compute node (limited)
# 2020 MBP → CI/CD runner
```

#### Option 2: Backup/Monitoring Stations
- Install Proxmox Backup Server
- Run Grafana dashboards 24/7
- Network monitoring station

#### Option 3: Sell and Reinvest
- 2019 15" MBP: ~$600-800
- 2020 13" MBP: ~$500-600
- **Total: $1100-1400**
- Use funds for mini-PC or server

## Remote Access Architecture

### Primary Access Methods

1. **Tailscale Mesh VPN**
```bash
# Install on all nodes
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --advertise-routes=10.0.0.0/8
```

2. **Cloudflare Tunnel**
```bash
# For public services without exposing IP
cloudflared tunnel create homelab
cloudflared tunnel route dns homelab *.yourdomain.com
```

3. **WireGuard Backup**
```bash
# Fallback if Tailscale is down
wg genkey | tee privatekey | wg pubkey > publickey
# Configure on router/firewall
```

### Connection Priority
```
1. Local Network (when home)
   → Direct connection
   
2. Tailscale (primary remote)
   → Automatic mesh routing
   → Works behind NAT
   
3. Cloudflare Tunnel (public services)
   → Web services only
   → No port forwarding needed
   
4. WireGuard (backup)
   → Manual failover
   → Requires port forward
```

## Performance Optimization

### For High Latency Connections

1. **Mosh Instead of SSH**
```bash
brew install mosh
mosh user@homelab
```

2. **VS Code Settings**
```json
{
  "remote.SSH.useLocalServer": true,
  "remote.SSH.remotePlatform": {
    "homelab": "linux"
  }
}
```

3. **tmux Configuration**
```bash
# ~/.tmux.conf
set -g mouse on
set -sg escape-time 0
set -g history-limit 50000
```

### Development Workflow

#### Local (on MacBook)
- Code editing
- Git operations
- Documentation
- Terraform planning

#### Remote (on Homelab)
- Building/compiling
- Testing
- Container operations
- Resource-intensive tasks

## Backup Strategy for Travel

### Before Travel Checklist
- [ ] Full homelab backup to NAS
- [ ] Sync critical data to mini-PC
- [ ] Test remote access from phone hotspot
- [ ] Configure wake-on-LAN
- [ ] Set up monitoring alerts
- [ ] Document emergency procedures
- [ ] Share IPMI access with trusted person

### Data Sync Strategy
```bash
# Bi-directional sync with homelab
rsync -avz --delete \
  homelab:/data/projects/ \
  /local/projects/

# Encrypted backup to cloud
restic backup \
  --repo s3:s3.amazonaws.com/bucket \
  /local/critical-data
```

## Cost Analysis

### Option Comparison

| Setup | Hardware Cost | Monthly Cost | Portability | Reliability |
|-------|--------------|--------------|-------------|-------------|
| MacBook Only | $0 | $0 | Excellent | Limited |
| + Cloud VMs | $0 | $100+ | Excellent | Good |
| + Mini-PC | $800 | $0 | Good | Excellent |
| + Colo Server | $0 | $50-100 | Poor | Excellent |

### Recommended: Hybrid Approach
1. MacBook Air M4 for interface
2. Homelab for primary compute
3. Mini-PC for travel > 2 weeks
4. Cloud for emergency failover

## Security Considerations

### Access Security
```yaml
Requirements:
  - SSH keys only (no passwords)
  - 2FA on Tailscale/Cloudflare
  - Fail2ban on all exposed services
  - Regular security updates
  
Monitoring:
  - Login alerts via ntfy
  - Unusual access patterns
  - Bandwidth monitoring
  - Service health checks
```

### Travel Security
- Use VPN on all public WiFi
- Encrypt mini-PC storage
- Separate travel SSH keys
- Geofencing alerts on homelab

## Emergency Procedures

### If Homelab Goes Down
1. Check monitoring dashboard
2. Try IPMI/iDRAC access
3. Contact trusted local person
4. Failover to cloud backup
5. Use mini-PC as temporary lab

### Recovery Priorities
1. Network connectivity
2. Proxmox management
3. Critical services
4. Development environment
5. Non-critical services

---

*Last Updated: January 2025*