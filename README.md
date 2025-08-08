# Dark Knight Homelab

**[Features](#features) • [Get Started](#get-started) • [Documentation](#documentation) • [Contributing](#contributing)**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg?style=flat-square)](https://www.gnu.org/licenses/gpl-3.0)
[![GitHub Stars](https://img.shields.io/github/stars/amir-parvin-group/dark-knight?style=flat-square&logo=github)](https://github.com/amir-parvin-group/dark-knight)
[![GitHub Issues](https://img.shields.io/github/issues/amir-parvin-group/dark-knight?style=flat-square)](https://github.com/amir-parvin-group/dark-knight/issues)

This project utilizes [Infrastructure as Code](https://en.wikipedia.org/wiki/Infrastructure_as_code) and [GitOps](https://www.weave.works/technologies/gitops) to automate provisioning, operating, and updating self-hosted services in my homelab.
It can be used as a highly customizable framework to build your own homelab.

> **What is a homelab?**
>
> Homelab is a laboratory at home where you can self-host, experiment with new technologies, practice for certifications, and so on.
> For more information, please see the [r/homelab introduction](https://www.reddit.com/r/homelab/wiki/introduction) and the
> [Home Operations Discord community](https://discord.gg/home-operations) (formerly known as [k8s-at-home](https://k8s-at-home.com)).

If you encounter an issue, please create [a bug report](https://github.com/amir-parvin-group/dark-knight/issues/new?template=bug_report.md).

## Overview

Project status: **ALPHA**

This project is still in the experimental stage, and I don't use anything critical on it.
Expect breaking changes that may require a complete redeployment.
A proper upgrade path is planned for the stable release.
More information can be found in [the roadmap](#roadmap) below.

## Architecture Overview

<img src="./assets/ProxmoxClusterStatus.png" alt="Proxmox Cluster Status" width="600" style="max-width:600px;display:block">

## Hardware

### Current Hardware Setup

<img src="./assets/Current HomeLab.jpeg" alt="Current HomeLab" width="600" style="max-width:600px;display:block">

<img src="./assets/HomeServer.jpg" alt="HomeServer" width="600" style="max-width:600px;display:block">
<img src="https://assets.raspberrypi.com/static/8f6eca535dbb23a21eb41a748050e3a0/f7ad0/16gb.webp" alt="Raspberry Pi 5" width="600" style="max-width:600px;display:block">
<img src="https://www.cudy.com/cdn/shop/files/A__GS108_1464x600-2.jpg" alt="Cudy Switch" width="600" style="max-width:600px;display:block">

- **Primary Home Server** (Custom Build):
  - CPU: `32 x AMD Ryzen 9 7950X 16-Core Processor (1 Socket)`
  - RAM: `128 GiB DDR5, 6000MHz`
  - SSD: `PCIe Gen5 2TB`
  - GPU: `ZOTAC GAMING GeForce RTX 4080 SUPER`
- **Raspberry Pi 5** (Secondary Node):
  - CPU: `4 x Cortex-A76 (1 Socket)`
  - RAM: `8 GiB DDR5`
  - SSD: `64 GiB`
- **Network Switch**: Cudy GS108 8-Port Gigabit Desktop Switch
  - Ports: `8`
  - Speed: `1000Mbps`

## Features

- [x] Automated backup and restore
- [ ] Automated Kubernetes installation and management
- [ ] Installing and managing applications using GitOps
- [ ] CI/CD platform
- [ ] Distributed storage
- [ ] Monitoring and alerting
- [ ] Common applications: Gitea, Jellyfin, Paperless...
- [ ] Automated bare metal provisioning with PXE boot
- [ ] Automatic rolling upgrade for OS and Kubernetes
- [ ] Automatically update apps (with approval)
- [ ] Modular architecture, easy to add or remove features/components
- [ ] Automatically update DNS records for exposed services
- [ ] Automated certificate management
- [ ] Expose services to the internet securely with [Cloudflare Tunnel](https://www.cloudflare.com/products/tunnel/)
- [ ] VPN (Tailscale or Wireguard)
- [ ] Private container registry
- [ ] Support multiple environments (dev, prod)
- [ ] Single sign-on
- [ ] Infrastructure testing

## Tech Stack

<table>
    <tr>
        <th>Logo</th>
        <th>Name</th>
        <th>Description</th>
    </tr>
    <tr>
        <td><img width="32" src="https://simpleicons.org/icons/proxmox.svg"></td>
        <td><a href="https://www.proxmox.com/en/">Proxmox VE</a></td>
        <td>An Open-source server management platform for enterprise virtualization</td>
    </tr>
    <tr>
        <td><img width="32" src="https://simpleicons.org/icons/proxmox.svg"></td>
        <td><a href="https://www.proxmox.com/en/products/proxmox-backup-server/overview">Proxmox Backup Server</a></td>
        <td>An enterprise backup solution, for backing up and restoring VMs, containers, and physical hosts</td>
    </tr>
    <tr>
        <td><img width="32" src="https://simpleicons.org/icons/truenas.svg"></td>
        <td><a href="https://www.truenas.com/">TrueNAS</a></td>
        <td>Provision, Manage and Access your NAS</td>
    </tr>
    <tr>
        <td><img width="32" src="https://simpleicons.org/icons/terraform.svg"></td>
        <td><a href="https://www.terraform.io/">Terraform</a></td>
        <td>Automate bare metal provisioning</td>
    </tr>
    <tr>
        <td><img width="32" src="https://simpleicons.org/icons/ansible.svg"></td>
        <td><a href="https://www.ansible.com">Ansible</a></td>
        <td>Automate bare metal configuration</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/13629408"></td>
        <td><a href="https://kubernetes.io">Kubernetes</a></td>
        <td>Container-orchestration system, the backbone of this project</td>
    </tr>
    <tr>
        <td><img width="32" src="https://simpleicons.org/icons/github.svg"></td>
        <td><a href="https://github.com">GitHub Self Hosted Runner</a></td>
        <td>Simple yet powerful CI/CD engine with great extensibility</td>
    </tr>
    <tr>
        <td><img width="32" src="https://longhorn.io/img/logos/longhorn-icon-black.png"></td>
        <td><a href="https://longhorn.io">Longhorn</a></td>
        <td>Cloud-Native Block Storage for Kubernetes</td>
    </tr>
    <tr>
        <td><img width="32" src="https://helm.sh/img/helm.svg"></td>
        <td><a href="https://helm.sh">Helm</a></td>
        <td>The package manager for Kubernetes</td>
    </tr>
    <!--
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/30269780"></td>
        <td><a href="https://argoproj.github.io/cd">ArgoCD</a></td>
        <td>GitOps tool built to deploy applications to Kubernetes</td>
    </tr>
    <tr>
        <td><img width="32" src="https://github.com/jetstack/cert-manager/raw/master/logo/logo.png"></td>
        <td><a href="https://cert-manager.io">cert-manager</a></td>
        <td>Cloud native certificate management</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/21054566?s=200&v=4"></td>
        <td><a href="https://cilium.io">Cilium</a></td>
        <td>eBPF-based Networking, Observability and Security (CNI, LB, Network Policy, etc.)</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/314135?s=200&v=4"></td>
        <td><a href="https://www.cloudflare.com">Cloudflare</a></td>
        <td>DNS and Tunnel</td>
    </tr>
    <tr>
        <td><img width="32" src="https://www.docker.com/wp-content/uploads/2022/03/Moby-logo.png"></td>
        <td><a href="https://www.docker.com">Docker</a></td>
        <td>Ephemeral PXE server</td>
    </tr>
    <tr>
        <td><img width="32" src="https://github.com/kubernetes-sigs/external-dns/raw/master/docs/img/external-dns.png"></td>
        <td><a href="https://github.com/kubernetes-sigs/external-dns">ExternalDNS</a></td>
        <td>Synchronizes exposed Kubernetes Services and Ingresses with DNS providers</td>
    </tr>
    <tr>
        <td><img width="32" src="https://upload.wikimedia.org/wikipedia/commons/thumb/3/3f/Fedora_logo.svg/267px-Fedora_logo.svg.png"></td>
        <td><a href="https://getfedora.org/en/server">Fedora Server</a></td>
        <td>Base OS for Kubernetes nodes</td>
    </tr>
    <tr>
        <td><img width="32" src="https://upload.wikimedia.org/wikipedia/commons/b/bb/Gitea_Logo.svg"></td>
        <td><a href="https://gitea.com">Gitea</a></td>
        <td>Self-hosted Git service</td>
    </tr>
    <tr>
        <td><img width="32" src="https://grafana.com/static/img/menu/grafana2.svg"></td>
        <td><a href="https://grafana.com">Grafana</a></td>
        <td>Observability platform</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/49319725"></td>
        <td><a href="https://k3s.io">K3s</a></td>
        <td>Lightweight distribution of Kubernetes</td>
    </tr>
    <tr>
        <td><img width="32" src="https://kanidm.com/images/logo.svg"></td>
        <td><a href="https://kanidm.com">Kanidm</a></td>
        <td>Modern and simple identity management platform</td>
    </tr>
    <tr>
        <td><img width="32" src="https://github.com/grafana/loki/blob/main/docs/sources/logo.png?raw=true"></td>
        <td><a href="https://grafana.com/oss/loki">Loki</a></td>
        <td>Log aggregation system</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/3380462"></td>
        <td><a href="https://prometheus.io">Prometheus</a></td>
        <td>Systems monitoring and alerting toolkit</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/1412239?s=200&v=4"></td>
        <td><a href="https://www.nginx.com">NGINX</a></td>
        <td>Kubernetes Ingress Controller</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/NixOS/nixos-artwork/refs/heads/master/logo/nix-snowflake-colours.svg"></td>
        <td><a href="https://nixos.org">Nix</a></td>
        <td>Convenient development shell</td>
    </tr>
    <tr>
        <td><img width="32" src="https://ntfy.sh/_next/static/media/logo.077f6a13.svg"></td>
        <td><a href="https://ntfy.sh">ntfy</a></td>
        <td>Notification service to send notifications to your phone or desktop</td>
    </tr>
    <tr>
        <td><img width="32" src="https://docs.renovatebot.com/assets/images/logo.png"></td>
        <td><a href="https://www.whitesourcesoftware.com/free-developer-tools/renovate">Renovate</a></td>
        <td>Automatically update dependencies</td>
    </tr>
    <tr>
        <td><img width="32" src="https://raw.githubusercontent.com/rook/artwork/master/logo/blue.svg"></td>
        <td><a href="https://rook.io">Rook Ceph</a></td>
        <td>Cloud-Native Storage for Kubernetes</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/48932923?s=200&v=4"></td>
        <td><a href="https://tailscale.com">Tailscale</a></td>
        <td>VPN without port forwarding</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/13991055?s=200&v=4"></td>
        <td><a href="https://www.wireguard.com">Wireguard</a></td>
        <td>Fast, modern, secure VPN tunnel</td>
    </tr>
    <tr>
        <td><img width="32" src="https://zotregistry.dev/v2.0.2/assets/images/logo.svg"></td>
        <td><a href="https://zotregistry.dev">Zot Registry</a></td>
        <td>Private container registry</td>
    </tr> -->
</table>

## Get Started

### Quick Start Options

1. **Local Development** - [Try it out locally](./installation/sandbox.md) without any hardware
2. **Production Deployment** - [Deploy on real hardware](./installation/production.md) for production workloads

## Documentation

### Core Components

- [Ansible Configuration](./ansible/README.md) - Infrastructure automation and configuration management
- [Kubernetes Setup](./docs/k8s.md) - Container orchestration and deployment
- [Proxmox Guide](./docs/proxmox/README.md) - Virtualization platform setup and management
- [Networking](./docs/networking.md) - Network configuration and topology

### Services & Applications

- [Pi-hole](./docs/pi-hole.md) - Network-wide ad blocking
- [TrueNAS Storage](./docs/manage-storage-with-truenas.md) - Network-attached storage management
- [GitHub Self-Hosted Runner](./docker/gh-self-hosted-runner/README.md) - CI/CD infrastructure

### Installation Guides

- [Sandbox Environment](./installation/sandbox.md) - Local testing environment
- [Production Environment](./installation/production.md) - Full production deployment
- [Proxmox Post-Installation](./docs/proxmox/proxmox-post-installation.md) - Initial setup after installation
- [VM Templates](./docs/proxmox/proxmox-vm-template.md) - Creating reusable VM templates
- [Storage Expansion](./docs/proxmox/increase-storage.md) - Adding storage to Proxmox

## Roadmap

See [roadmap](./roadmap.md) and [open issues](https://github.com/amir-parvin-group/dark-knight/issues) for a list of proposed features and known issues.

## Contributing

Any contributions you make are greatly appreciated.

Please see [contributing guide](./CONTRIBUTE.md) for more information.

## License

Copyright &copy; 2025 - \* ProxyServer2023

Distributed under the GPLv3 License.
See [license page](./LICENSE.md) for more information.

## Acknowledgements

### References & Inspiration

- [Jeff CTO - HomeLab](https://www.youtube.com/@jeffsponaugle6339)
- [Homelab - Khue Doan](https://homelab.khuedoan.com/)

### Contributors

We appreciate all contributions to this project! Special thanks to:

- [@proxyserver2023](https://github.com/proxyserver2023) - Project creator and maintainer

If you've contributed and aren't listed here, please feel free to add yourself in a PR.

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=amir-parvin-group/dark-knight&type=Date)](https://star-history.com/#amir-parvin-group/dark-knight&Date)
