# Homelab Roadmap & Hardware Purchase Plan

This document outlines your journey to build a robust Home Lab—from foundational infrastructure through advanced orchestration and AI/ML workloads—and organizes the necessary hardware into phases. It also includes sample product links for reference.

---

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
- **Cluster Setup**
  - [ ] Build a High Availability Kubernetes cluster (using Kubeadm or K3s).
- **Persistent Storage**
  - [ ] Implement on-prem persistent storage solutions using Longhorn or Ceph.
- **Ingress & Load Balancing**
  - [ ] Deploy production-grade ingress using MetalLB and Nginx.
- **Security & Policies**
  - [ ] Configure RBAC, Pod Security Policies, and Network Policies.
- **Monitoring & Logging**
  - [ ] Set up advanced monitoring with Prometheus, Grafana, and Loki.
- **Resilience & Scalability**
  - [ ] Implement Kubernetes auto-scaling and self-healing mechanisms.
  - [ ] Develop Disaster Recovery (DR) and backup strategies.
- **Service Mesh & Multi-Tenancy**
  - [ ] Integrate a service mesh with Istio or Linkerd.
  - [ ] Explore multi-tenancy via virtual clusters.
- **Application Deployments**
  - [ ] Deploy stateful services: Kafka, Redis, PostgreSQL, or MongoDB.
  - [ ] Experiment with AI/ML workloads using NVIDIA GPU passthrough.
- **Container Registry & CI/CD**
  - [ ] Deploy Harbor as a private Docker registry.
  - [ ] Implement a GitOps workflow with Argo CD and a CI/CD pipeline using Jenkins.
- **Infrastructure as Code**
  - [ ] Utilize Terraform for provisioning and Ansible for configuration management.

### AI/ML Workloads
- *(Work in Progress as hardware scales)*

### Equipment & Hardware Considerations
- **Networking Hardware:** Upgrade to a 10GbE switch now and plan for future 100GbE networking.
- **Storage & Compute Expansion:** Add extra SSDs and compute nodes as demand grows.
- **Rack & Power:** Invest in a 42U rack cabinet and ensure stable power with a UPS.
- **Security:** Deploy a dedicated hardware firewall (pfSense/OPNsense).

---

## 2. Hardware Purchase Plan – 42U Proxmox HomeLab

The hardware is organized into four phases, allowing you to start with a minimum setup and scale up as your lab evolves.

### 🔹 Phase 1: Core Infrastructure & Management

| Item                        | Description                                               | Qty | Unit Price (Est.) | Notes                           | Product Link |
|-----------------------------|-----------------------------------------------------------|-----|-------------------|---------------------------------|--------------|
| **Proxmox Base Node**       | 1U Server, AMD EPYC/Xeon, 64–96GB ECC RAM, 2x 1.92TB NVMe  | 1   | $1,800–$2,500     | Bootstrap node for management   | [Supermicro 1U Server](https://www.supermicro.com/en/products/system/1u) |
| **Management Switch (1GbE)**| 24/48-port L2+ Managed Switch (VLAN capable)              | 1   | $200–$500         | For management and IPMI         | [Cisco SG350-28](https://www.cisco.com/c/en/us/products/switches/sg350-28-managed-switch/index.html) |
| **pfSense/OPNsense Appliance**| 1U Mini Box with 2–4 NICs                             | 1   | $300–$700         | UTM firewall, VPN gateway       | [Netgate SG-1100](https://www.netgate.com/appliances/sg-1100/) |
| **UPS**                     | 1500VA+ Smart UPS                                        | 1   | $300–$600         | Power backup                    | [APC Smart-UPS 1500VA](https://www.apc.com/shop/us/en/products/APC-Smart-UPS-1500VA-LCD-120V/P-SMT1500) |
| **Smart PDU**               | Metered/Switched 8–12 Outlets                            | 1   | $250–$500         | Remote power control            | [APC Smart PDU](https://www.apc.com/shop/us/en/products/APC-Smart-PDU-by-APC-6-outlet-220V/P-AP8959) |

---

### 🔹 Phase 2: GPU Compute & High-Speed Networking

| Item                     | Description                                                                 | Qty | Unit Price (Est.)   | Notes                             | Product Link |
|--------------------------|-----------------------------------------------------------------------------|-----|---------------------|-----------------------------------|--------------|
| **GPU Compute Node**     | 2U Dual EPYC, 512GB RAM, 2x A100/H100/RTX 6000 ADA, 4x NVMe                   | 2   | $8,000–$25,000      | For AI training & inference       | [ASUS ESC8000 G4](https://www.asus.com/Commercial-Servers-Workstations/ESC8000-G4/) |
| **Top-of-Rack Switch**   | 25/100GbE L3 Switch (Mellanox/Aruba/MikroTik CRS)                           | 1   | $1,000–$4,000       | High-speed data & storage fabric  | [Mellanox Spectrum SN2700](https://www.mellanox.com/products/switches/spectrum-sn2700) |
| **High-Speed NICs**      | Dual-port 25/100GbE RDMA NICs                                               | 2–4 | $200–$800 each      | For compute & storage nodes       | [Mellanox ConnectX-5](https://www.mellanox.com/products/network-adapters/ethernet) |
| **DAC/Fiber Cables**     | 10–100Gbps short-run connections                                            | 4–8 | $30–$70 each        | For high-speed interconnects        | [Mellanox DAC Cable](https://www.mellanox.com/products/cables/dac) |

---

### 🔹 Phase 3: Storage Cluster / Data Lake

| Item                     | Description                                                                 | Qty | Unit Price (Est.)   | Notes                             | Product Link |
|--------------------------|-----------------------------------------------------------------------------|-----|---------------------|-----------------------------------|--------------|
| **Ceph Storage Node**    | 2U, 256GB RAM, 12x 12TB HDD, 2x 1TB NVMe for DB/WAL                        | 3   | $3,500–$6,000       | Ceph storage node                 | [Supermicro 2U Storage Node](https://www.supermicro.com/en/products/system/2u/storage) |
| **Enterprise HDDs**      | 12–18TB 7200RPM drives (e.g., Seagate Exos, WD Gold)                        | 36+ | $200–$300 each      | High-capacity OSD drives          | [Seagate Exos X16](https://www.seagate.com/internal-hard-drives/exos/) |
| **NVMe for WAL/DB**      | 1TB Gen4 NVMe (Samsung PM983/SN850X)                                        | 6   | $100–$150 each      | For Ceph journal/cache            | [Samsung PM983](https://www.samsung.com/semiconductor/minisite/ssd/product/enterprise/pm983/) |
| **ZFS NAS Node (Optional)** | 2U ZFS System, 8–12 drives (RAIDZ2/Striped Mirror)                      | 1   | $2,000–$3,500       | For cold storage/snapshots        | [Synology RackStation RS3617xs](https://www.synology.com/en-global/products/rs3617xs) |

---

### 🔹 Phase 4: Backup, Monitoring & Expansion

| Item                     | Description                                                                 | Qty | Unit Price (Est.)   | Notes                             | Product Link |
|--------------------------|-----------------------------------------------------------------------------|-----|---------------------|-----------------------------------|--------------|
| **Proxmox Backup Server**| 1U server, ZFS pool, 64–128GB RAM                                           | 1   | $1,500–$2,500       | For daily backups                 | [HPE ProLiant MicroServer Gen10 Plus](https://www.hpe.com/us/en/product-catalog/servers/proliant-servers/pip.microserver.html) |
| **Monitoring Node**      | 1U/Mini Server (Grafana, Prometheus, Loki, node_exporter)                   | 1   | $300–$800           | Infrastructure monitoring         | [ASUS PN50 Mini PC](https://www.asus.com/us/Mini-PCs/ASUS-PN50/) |
| **Expansion Compute Nodes**| Additional Proxmox VE nodes (similar to Phase 1 base node)               | 2–4 | $1,800–$2,200 each  | For scaling out the cluster       | [Supermicro 1U Server](https://www.supermicro.com/en/products/system/1u) |
| **External Backup (NAS)**| Synology/QNAP NAS or JBOD for cold storage                                  | 1   | $500–$2,000         | For offsite/cold backup           | [Synology DiskStation DS920+](https://www.synology.com/en-global/products/DS920+) |

---

## 3. Summary Budget

| Phase   | Purpose                              | Estimated Cost Range     |
|---------|--------------------------------------|--------------------------|
| Phase 1 | Core Infrastructure & Management     | $2,500 – $4,500          |
| Phase 2 | GPU Compute & High-Speed Networking  | $15,000 – $50,000+       |
| Phase 3 | Storage Cluster / Data Lake          | $12,000 – $25,000+       |
| Phase 4 | Backup, Monitoring & Expansion       | $4,000 – $8,000          |

---
