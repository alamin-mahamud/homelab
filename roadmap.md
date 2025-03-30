# Homelab Roadmap & Hardware Purchase Plan

This document outlines your journey to build a robust Home Lab—from foundational infrastructure through advanced orchestration and AI/ML workloads—and organizes the necessary hardware into phases. It also includes sample product links for reference.

## 1. Homelab Roadmap

### Foundation & Infrastructure Setup

- **Initial Equipment Integration**
  - [x] Utilize existing desktops and Raspberry Pi clusters.
  - [x] Organize basic network gear: router, switches, patch cords.
- **Networking & Security**
  - [x] Configure VLANs and secure remote access channels.
- **Storage**
  - [ ] Deploy TrueNAS for centralized storage management.

### Proxmox Mastery & Virtualization

- **Proxmox Cluster**
  - [x] Build a multi-node Proxmox cluster with High Availability (HA) for VM failover.
- **Networking**
  - [x] Configure Proxmox networking and VLANs to support container and VM workloads.
- **Virtualized Environments**
  - [ ] Set up Ubuntu Desktop on Proxmox with GPU support.
  - [ ] Secure the lab with SSL certificates.

### Kubernetes Mastery & Container Orchestration

- [x] **Cluster Setup** - Build a High Availability Kubernetes cluster (using Kubeadm or K3s).
- [ ] **Persistent Storage** - Implement on-prem persistent storage solutions using Longhorn or Ceph.
- [ ] **Ingress & Load Balancing** - Deploy production-grade ingress using MetalLB and Nginx.
- [ ] **Security & Policies** - Configure RBAC, Pod Security Policies, and Network Policies.
- [ ] **Monitoring & Logging** - Set up advanced monitoring with Prometheus, Grafana, and Loki.
- [ ] **Resilience & Scalability** - Implement Kubernetes auto-scaling, self-healing mechanisms with DR.
- [ ] **Service Mesh** - Integrate a service mesh with Istio or Linkerd.
- [ ] **Multi-Tenancy** - Explore multi-tenancy via virtual clusters.
- **Application Deployments**
  - [ ] Deploy stateful services: Kafka, Redis, PostgreSQL, or MongoDB.
  - [ ] Experiment with AI/ML workloads using NVIDIA GPU passthrough.
- **Container Registry & CI/CD**
  - [ ] Deploy Harbor as a private Docker registry.
  - [ ] Implement a GitOps workflow with Argo CD and a CI/CD pipeline using Jenkins.
- **Infrastructure as Code**
  - [ ] Utilize Terraform for provisioning and Ansible for configuration management.

### AI/ML Workloads

- _(Work in Progress as hardware scales)_

## 2. Hardware Purchase Plan – 42U Proxmox HomeLab

### 42U Rack Server ( WIP )

| U   | Device / Function                                                                   | Description                                                |
| --- | ----------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| 1U  | Cable Management Arm                                                                | Top-side cable routing                                     |
| 1U  | [Top-of-Rack 10GbE Switch](https://store.ui.com/us/en/products/udm-pro)             | Management & IPMI Network                                  |
| 1U  | [Patch Panel](https://www.startech.com.bd/rosenberger-1u-metal-cable-manager-panel) | Network cabling and cross-connect                          |
| 18U | Compute Node(s)                                                                     | Proxmox VE, 16C 32T, 128GB Non-ECC RAM, 1x 2TB NVMe, 1 GPU |
| 14U | Ceph Storage Node(s)                                                                | 12-bay + 2x NVMe for WAL/DB - 256GB RAM                    |
| 1U  | KVM-over-IP / Console Server                                                        | Remote BIOS/Boot access for all nodes                      |
| 4U  | UPS #1 (Battery Backup)                                                             | Clean shutdown for critical systems                        |
| 1U  | 1U Utility Drawer (Optional)                                                        | USBs, tools, SSDs, network testers                         |
| 1U  | PDU A (Smart or Metered)                                                            | For even power distribution                                |

The hardware is organized into four phases, allowing me to start with a minimum setup and scale up as my lab evolves.

### 🔹 Phase 0: Start Homelab

| Item               | Description                                                 | Qty | Unit Price (Est.) | Notes                        | Purchased |
| ------------------ | ----------------------------------------------------------- | --- | ----------------- | ---------------------------- | --------- |
| **Home Server**    | 2U Server, AMD Ryzen, 128GB Non-ECC RAM, 1x 2TB NVMe, 1 GPU | 1   | $3,500            | General Purpose Home Server  | √         |
| **Raspberry Pi 5** | 4 CPU, 8GB RAM, 64GB                                        | 1   | $200              | Small, Lightweight workloads | √         |
| **Desktop Switch** | 8 Port Gigabit Switch - Unmanaged                           | 1   | $15               | Unmanaged Switch             | √         |
| **TP-Link Router** | AX6600 Tri-Band Gigabit Wi-Fi 6 Router                      | 1   | $200              | Wifi 6 + LAN                 | √         |

### 🔹 Phase Next: NAS Storage

| Item                  | Description                    | Qty | Unit Price (Est.) | Notes         | Purchased / Link                                          |
| --------------------- | ------------------------------ | --- | ----------------- | ------------- | --------------------------------------------------------- |
| **NAS Server**        | 2U Server, 20TB HDD            | 1   | $2,000            | NAS           | [192 TB NAS](https://www.youtube.com/watch?v=nKeENirsiTs) |
| **CloudFlare Access** | Secure Access to your Services | 1   | $5 per Month      | Secure Access |                                                           |

### 🔹 Phase Later: Server Infras

| Item                          | Description                               | Qty | Unit Price | Notes                   | Product Link                                                                   |
| ----------------------------- | ----------------------------------------- | --- | ---------- | ----------------------- | ------------------------------------------------------------------------------ |
| **42U Rack**                  | 42U Rack                                  | 1   | $500       | Rack                    | [Toten 42U Rack](https://www.startech.com.bd/toten-el28100-42-42u-server-rack) |
| **Management Switch (10GbE)** | 10G Cloud Gateway with 100+ UniFi device. | 1   | $400       | For management and IPMI | [UDM Pro](https://store.ui.com/us/en/products/udm-pro)                         |
| **PDU**                       | PDU.                                      | 1   | $35        | PDU                     | [PDU](https://www.ryans.com/toten-10-port-aluminum-pdu-for-server-rack)        |

### 🔹 Phase Later: High-Speed Networking

| Item                | Description                   | Qty | Unit Price (Est.) | Notes                       | Product Link                                                                       |
| ------------------- | ----------------------------- | --- | ----------------- | --------------------------- | ---------------------------------------------------------------------------------- |
| **High-Speed NICs** | Dual-port 25/100GbE RDMA NICs | 1   | $500              | For compute & storage nodes | [Mellanox ConnectX-5](https://www.mellanox.com/products/network-adapters/ethernet) |

### 🔹 Phase Later: Storage Cluster / Data Lake

| Item                | Description         | Qty | Unit Price (Est.) | Notes                    | Product Link                                                           |
| ------------------- | ------------------- | --- | ----------------- | ------------------------ | ---------------------------------------------------------------------- |
| **Enterprise HDDs** | 24TB 7200RPM drives | TBD | $500 each         | High-capacity OSD drives | [Seagate Exos X24](https://www.seagate.com/internal-hard-drives/exos/) |

### 🔹 Phase Later: Firewall, UPS

| Item                           | Description               | Qty | Unit Price (Est.) | Notes                     | Product Link                                                   |
| ------------------------------ | ------------------------- | --- | ----------------- | ------------------------- | -------------------------------------------------------------- |
| **pfSense/OPNsense Appliance** | 1U Mini Box with 2–4 NICs | 1   | $300–$700         | UTM firewall, VPN gateway | [Netgate SG-1100](https://www.netgate.com/appliances/sg-1100/) |
| **UPS**                        | 1500VA+ Smart UPS         | 1   | $300–$600         | Power backup              | [APC Smart-UPS 1500VA]()                                       |

## 3. Summary Budget

| Purpose                     | Estimated Cost Range |
| --------------------------- | -------------------- |
| Start HomeLab               | $4000                |
| NAS Storage                 | $2000                |
| Server Infras               | $1500                |
| High-Speed Networking       | $500                 |
| FireWall, UPS               | $1000                |
| Storage Cluster / Data Lake | $TBD+                |

## ☀️ Solar Power Plan for 42U Rack Homelab

This plan outlines the solar and battery requirements to run a full-blown Proxmox-based 42U rack homelab on renewable energy.

### ⚙️ System Load & Configuration ( Hypothetical Data Center with Renewable Energy)

| Item                        | Phase-1 Value | Phase-2 Value | Phase-3 Value |
| --------------------------- | ------------- | ------------- | ------------- |
| **Estimated Power Load**    | 2.5 kW        | 5 kW          | 10 kW         |
| **Daily Energy Usage**      | 60 kWh/day    | 120 kWh/day   | 240 kWh/day   |
| **Solar Array Size**        | 12 kW         | 25 kW         | 50 kW         |
| **Average Sunlight Hours**  | 5 hours/day   | 5 hours/day   | 5 hours/day   |
| **Battery Backup Capacity** | 25 kWh        | 50 kWh        | 100 kWh       |

### ☀️ Solar & Battery Performance

| Metric                        | Phase-1 Value             | Phase-2 Value           | Phase-3 Value            |
| ----------------------------- | ------------------------- | ----------------------- | ------------------------ |
| **Daily Solar Generation**    | 60 kWh/day                | 125 kWh/day             | 250 kWh/day              |
| **Daily Surplus/Deficit**     | +2.5 kWh/day (surplus) ✅ | +5 kWh/day (surplus) ✅ | +10 kWh/day (surplus) ✅ |
| **Overnight Load (12 hours)** | 30 kWh                    | 60 kWh                  | 120 kWh                  |
| **Battery Coverage**          | 83.3% of night load 🔋    | 83.3% of night load 🔋  | 83.3% of night load 🔋   |

### 💰 Financial Impact (🇧🇩 Bangladesh)

| Metric                       | Phase-1 Value        | Phase-2 Value        | Phase-3 Value        |
| ---------------------------- | -------------------- | -------------------- | -------------------- |
| **Electricity Cost**         | ৳10 per kWh (est.)   | ৳10 per kWh (est.)   | ৳10 per kWh (est.)   |
| **Annual Energy Usage**      | 22,000 kWh           | 45,000 kWh           | 87,600 kWh           |
| **Annual Savings**           | **৳220,000/year** 💸 | **৳450,000/year** 💸 | **৳876,000/year** 💸 |
| **Estimated System Cost**    | ~**৳2,500,000**      | ~**৳5,000,000**      | ~**৳10,000,000**     |
| **Estimated Payback Period** | **~11 years** 🕒     | **~11 years** 🕒     | **~11 years** 🕒     |
