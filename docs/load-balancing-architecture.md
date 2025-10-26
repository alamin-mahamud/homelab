# Load Balancing Architecture: MetalLB + Traefik

This document explains how load balancing works in the homelab Kubernetes cluster, covering both Layer 4 (MetalLB) and Layer 7 (Traefik) load balancing.

## Table of Contents
1. [OSI Model Overview](#osi-model-overview)
2. [Layer 4 vs Layer 7 Load Balancing](#layer-4-vs-layer-7-load-balancing)
3. [MetalLB: Layer 4 Load Balancer](#metallb-layer-4-load-balancer)
4. [Traefik: Layer 7 Ingress Controller](#traefik-layer-7-ingress-controller)
5. [Complete Traffic Flow](#complete-traffic-flow)
6. [Architecture Diagrams](#architecture-diagrams)

---

## OSI Model Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      OSI Model Layers                       │
├──────┬──────────────────────────────────────────────────────┤
│ L7   │ Application  │ HTTP, HTTPS, DNS, FTP              │
│      │              │ • HTTP headers, paths, methods      │
│      │              │ • Cookie-based routing              │
│      │              │ • SSL/TLS termination               │
├──────┼──────────────┼─────────────────────────────────────┤
│ L6   │ Presentation │ SSL/TLS, MIME                       │
├──────┼──────────────┼─────────────────────────────────────┤
│ L5   │ Session      │ NetBIOS, RPC                        │
├──────┼──────────────┼─────────────────────────────────────┤
│ L4   │ Transport    │ TCP, UDP                            │ ← MetalLB
│      │              │ • Source/Destination Port           │
│      │              │ • Connection state                  │
│      │              │ • Load balancing based on IP:Port   │
├──────┼──────────────┼─────────────────────────────────────┤
│ L3   │ Network      │ IP, ICMP, ARP                       │
├──────┼──────────────┼─────────────────────────────────────┤
│ L2   │ Data Link    │ Ethernet, MAC addresses             │
├──────┼──────────────┼─────────────────────────────────────┤
│ L1   │ Physical     │ Cables, switches                    │
└──────┴──────────────┴─────────────────────────────────────┘

                      ↑ Traefik operates here (L7)
                      ↑ MetalLB operates here (L4)
```

---

## Layer 4 vs Layer 7 Load Balancing

### Layer 4 (Transport Layer)
**What it knows:**
- Source IP address
- Destination IP address
- Source Port
- Destination Port
- Protocol (TCP/UDP)

**What it CANNOT see:**
- HTTP headers
- URL paths
- Cookies
- Request methods (GET, POST, etc.)

**Characteristics:**
- ✅ Very fast (simple packet inspection)
- ✅ Protocol agnostic (works with any TCP/UDP traffic)
- ✅ Low latency
- ❌ No content-based routing
- ❌ No SSL termination
- ❌ Limited routing logic

### Layer 7 (Application Layer)
**What it knows:**
- Everything from Layer 4, PLUS:
- HTTP/HTTPS headers
- URL paths and query parameters
- Cookies and session data
- Request methods (GET, POST, PUT, DELETE)
- Host headers (virtual hosting)

**Characteristics:**
- ✅ Content-based routing (path, header, cookie-based)
- ✅ SSL/TLS termination
- ✅ Advanced features (rate limiting, auth, rewrites)
- ✅ Host-based routing
- ❌ Slower than L4 (more processing)
- ❌ HTTP/HTTPS specific

---

## MetalLB: Layer 4 Load Balancer

### What is MetalLB?

MetalLB is a **bare-metal Layer 4 load balancer** for Kubernetes. It provides LoadBalancer services in environments that don't have cloud provider integration (like AWS ELB, GCP Load Balancer).

### Operating Mode: L2 (Layer 2)

Our deployment uses **L2 mode** (ARP-based):

```yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: homelab-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - homelab-pool
```

### How L2 Mode Works

```
┌────────────────────────────────────────────────────────────────┐
│          Client (anywhere on 10.1.1.0/24 network)              │
│                      e.g., 10.1.1.5                            │
└────────────────────────────┬───────────────────────────────────┘
                             │
                             │ 1. Client wants to reach 10.1.1.100
                             │    (Traefik LoadBalancer IP)
                             ↓
┌────────────────────────────────────────────────────────────────┐
│                      Network Switch                            │
│                   (Layer 2 broadcast domain)                   │
└──────┬────────────────┬────────────────┬───────────────────────┘
       │                │                │
       ↓                ↓                ↓
   ┌────────┐      ┌────────┐      ┌────────┐
   │ Master1│      │Worker 1│      │Worker 2│
   │10.1.1.11│      │10.1.1.31│      │10.1.1.32│
   └────────┘      └────────┘      └────────┘
                        ↑
                        │ 2. MetalLB speaker on this node
                        │    responds to ARP request for 10.1.1.100
                        │    "10.1.1.100 is at MAC: xx:xx:xx:xx"
                        │
                   [Leader Election]
```

**Process:**
1. Client sends ARP request: "Who has 10.1.1.100?"
2. MetalLB **speaker pod** (elected leader) responds: "I do! Send packets to my MAC address"
3. Switch learns the association: `10.1.1.100 → Node MAC address`
4. All traffic to 10.1.1.100 flows to that node
5. kube-proxy forwards traffic to Traefik pods (across nodes if needed)

### IP Address Pool

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: homelab-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.1.1.100-10.1.1.150  # Pool of 51 IPs
```

**Allocation:**
- First LoadBalancer service gets: **10.1.1.100** (Traefik)
- Next service gets: **10.1.1.101**
- And so on...

### MetalLB Components

```
┌─────────────────────────────────────────────────────────────┐
│                     MetalLB System                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────┐         ┌──────────────────┐         │
│  │   Controller     │         │    Speaker       │         │
│  │  (Deployment)    │         │   (DaemonSet)    │         │
│  │                  │         │                  │         │
│  │ • Watches for    │         │ • Runs on EVERY  │         │
│  │   LoadBalancer   │────────▶│   node           │         │
│  │   services       │         │ • Announces IPs  │         │
│  │ • Assigns IPs    │         │   via ARP (L2)   │         │
│  │   from pool      │         │ • Leader election│         │
│  └──────────────────┘         └──────────────────┘         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Is MetalLB Layer 4 or Layer 7?

**Answer: Layer 4 (with Layer 2 announcement)**

MetalLB operates at **Layer 4** for load balancing:
- It assigns **IP addresses** to services
- It routes traffic based on **IP:Port** combinations
- It uses **Layer 2 (ARP)** to announce these IPs to the network
- It does **NOT** inspect HTTP headers, paths, or application data

**Think of MetalLB as:**
- A way to get **external IPs** in bare-metal Kubernetes
- The equivalent of cloud provider load balancers (AWS ELB, GCP LB)
- A **network-level** service that makes Kubernetes services accessible from outside the cluster

---

## Traefik: Layer 7 Ingress Controller

### What is Traefik?

Traefik is a **Layer 7 reverse proxy and load balancer** that routes HTTP/HTTPS traffic based on:
- Hostnames (`app1.example.com`, `app2.example.com`)
- URL paths (`/api`, `/admin`, `/static`)
- HTTP headers
- Request methods

### Traefik Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    Traefik Pod                           │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌────────────────────────────────────────────────┐     │
│  │           Entry Points                         │     │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐     │     │
│  │  │   :80    │  │   :443   │  │  :8080   │     │     │
│  │  │  (web)   │  │(websecure)│ │(dashboard)│     │     │
│  │  └─────┬────┘  └─────┬────┘  └──────────┘     │     │
│  └────────┼─────────────┼───────────────────────┘     │
│           │             │                              │
│           ↓             ↓                              │
│  ┌────────────────────────────────────────────────┐     │
│  │              Routers                           │     │
│  │  • Match by Host: app.example.com             │     │
│  │  • Match by Path: /api/*                      │     │
│  │  • Match by Header: X-Custom: value           │     │
│  └────────┬────────────────────────────────┬──────┘     │
│           │                                │            │
│           ↓                                ↓            │
│  ┌────────────────┐              ┌────────────────┐     │
│  │  Middlewares   │              │   Services     │     │
│  │  • Auth        │              │  • Backend pods│     │
│  │  • Rate limit  │              │  • Load balance│     │
│  │  • Redirects   │              │    across pods │     │
│  └────────────────┘              └────────────────┘     │
└──────────────────────────────────────────────────────────┘
```

### How Traefik Routes Traffic

#### Example 1: Host-based Routing

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-host-ingress
spec:
  ingressClassName: traefik
  rules:
  - host: grafana.homelab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 3000
  - host: prometheus.homelab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus
            port:
              number: 9090
```

**Traffic Flow:**
```
http://grafana.homelab.local
         ↓
   [Traefik inspects Host header]
         ↓
   Host: grafana.homelab.local → Route to Grafana service
   Host: prometheus.homelab.local → Route to Prometheus service
```

#### Example 2: Path-based Routing

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-based-ingress
spec:
  ingressClassName: traefik
  rules:
  - http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

**Traffic Flow:**
```
http://10.1.1.100/api/users
         ↓
   [Traefik inspects URL path]
         ↓
   /api/* → Route to api-service
   /web/* → Route to web-service
```

### Traefik vs NGINX Ingress

| Feature | Traefik | NGINX Ingress |
|---------|---------|---------------|
| Configuration | CRDs + Ingress | Annotations + Ingress |
| Dashboard | Built-in | Requires setup |
| Auto-discovery | Excellent | Good |
| Learning curve | Medium | Higher |
| Performance | Excellent | Excellent |

---

## Complete Traffic Flow

### Scenario: External client accessing Grafana

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         External Client                                  │
│                    (Browser at 10.1.1.5)                                 │
│                                                                          │
│  User types: http://grafana.homelab.local                               │
│  DNS resolves to: 10.1.1.100                                            │
└────────────────────────────────┬─────────────────────────────────────────┘
                                 │
                                 │ HTTP GET /
                                 │ Host: grafana.homelab.local
                                 ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                        LAYER 4: MetalLB                                 │
│                                                                         │
│  1. ARP Resolution:                                                     │
│     Client: "Who has 10.1.1.100?"                                      │
│     MetalLB Speaker (Worker 1): "I do! MAC: aa:bb:cc:dd:ee:ff"         │
│                                                                         │
│  2. Packet Forwarding:                                                  │
│     Dest IP: 10.1.1.100                                                │
│     Dest Port: 80                                                       │
│     Protocol: TCP                                                       │
│                                                                         │
│  → Forwards to any Traefik pod (via kube-proxy/iptables)              │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ Raw TCP connection
                                 │ Still just IP:Port
                                 ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                        LAYER 7: Traefik                                 │
│                                                                         │
│  3. HTTP Parsing:                                                       │
│     ┌─────────────────────────────────────────┐                        │
│     │ GET / HTTP/1.1                          │                        │
│     │ Host: grafana.homelab.local             │  ← Traefik reads this! │
│     │ User-Agent: Mozilla/5.0                 │                        │
│     │ Accept: text/html                       │                        │
│     └─────────────────────────────────────────┘                        │
│                                                                         │
│  4. Routing Decision:                                                   │
│     Host: grafana.homelab.local                                        │
│       → Matches Ingress rule                                           │
│       → Route to Service: kube-prometheus-stack-grafana                │
│       → Port: 80                                                        │
│                                                                         │
│  5. Load Balancing (L7):                                               │
│     Traefik balances across Grafana pod replicas                       │
│     (Round-robin, least-conn, etc.)                                    │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ Proxied HTTP request
                                 ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                   Kubernetes Service (ClusterIP)                        │
│              kube-prometheus-stack-grafana:80                           │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ kube-proxy routes to pod
                                 ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                          Grafana Pod                                    │
│                      (10.244.2.45:3000)                                │
│                                                                         │
│  Grafana application receives request and responds                     │
└─────────────────────────────────────────────────────────────────────────┘
```

### Step-by-Step Breakdown

#### Step 1: DNS Resolution
```
grafana.homelab.local → 10.1.1.100 (Traefik LoadBalancer IP)
```

#### Step 2: Layer 4 (MetalLB)
```
Client: ARP request "Who has 10.1.1.100?"
MetalLB Speaker (on Worker-1): "I have it! MAC: aa:bb:cc:dd:ee:ff"
Switch: Updates ARP table, forwards all 10.1.1.100 traffic to Worker-1
```

**MetalLB Decision Making:**
- Does NOT look at HTTP headers
- Only knows: `10.1.1.100:80` (TCP)
- Forwards to Traefik service endpoints

#### Step 3: Layer 7 (Traefik)
```
Traefik receives TCP connection, terminates it
Parses HTTP request:
  - Method: GET
  - Path: /
  - Host: grafana.homelab.local  ← KEY ROUTING DECISION

Matches Ingress rule:
  - Host: grafana.homelab.local → grafana service

Opens new connection to Grafana pod
Proxies request and response
```

**Traefik Decision Making:**
- Parses full HTTP request
- Inspects Host header
- Applies routing rules
- Performs L7 load balancing across backend pods

---

## Architecture Diagrams

### Diagram 1: Full Network Architecture

```
┌────────────────────────────────────────────────────────────────────────────┐
│                          External Network                                  │
│                            10.1.1.0/24                                     │
│                                                                            │
│   ┌──────────────┐      ┌──────────────┐      ┌──────────────┐           │
│   │   Client 1   │      │   Client 2   │      │   Client 3   │           │
│   │  10.1.1.5    │      │  10.1.1.6    │      │  10.1.1.7    │           │
│   └──────┬───────┘      └──────┬───────┘      └──────┬───────┘           │
│          │                     │                     │                    │
│          └─────────────────────┴─────────────────────┘                    │
│                                │                                          │
│                                │ All request 10.1.1.100                   │
└────────────────────────────────┼──────────────────────────────────────────┘
                                 │
                                 ↓
┌────────────────────────────────────────────────────────────────────────────┐
│                        Physical Network Layer                              │
│                          Gigabit Switch                                    │
│                                                                            │
│  ARP Table:                                                               │
│  10.1.1.100 → MAC: aa:bb:cc:dd:ee:ff (Worker-1)  ← MetalLB announcement  │
└────────────────────────────────────────────────────────────────────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
        ↓                        ↓                        ↓
┌──────────────┐        ┌──────────────┐        ┌──────────────┐
│   Master-1   │        │   Worker-1   │        │   Worker-2   │
│  10.1.1.11   │        │  10.1.1.31   │        │  10.1.1.32   │
├──────────────┤        ├──────────────┤        ├──────────────┤
│              │        │              │        │              │
│ K8s Control  │        │ MetalLB      │        │ MetalLB      │
│ Plane        │        │ Speaker      │        │ Speaker      │
│              │        │  [LEADER]    │        │ [STANDBY]    │
│              │        │      │       │        │              │
│              │        │      ↓       │        │              │
│              │        │ ┌─────────┐  │        │ ┌─────────┐  │
│              │        │ │ Traefik │  │        │ │ Traefik │  │
│              │        │ │  Pod 1  │  │        │ │  Pod 2  │  │
│              │        │ └────┬────┘  │        │ └────┬────┘  │
│              │        │      │       │        │      │       │
│              │        │      ↓       │        │      ↓       │
│              │        │ ┌─────────┐  │        │ ┌─────────┐  │
│              │        │ │ Grafana │  │        │ │  API    │  │
│              │        │ │  Pod    │  │        │ │  Pod    │  │
│              │        │ └─────────┘  │        │ └─────────┘  │
└──────────────┘        └──────────────┘        └──────────────┘

         │                       │                       │
         └───────────────────────┴───────────────────────┘
                                 │
                      Pod Network (Flannel)
                        10.244.0.0/16
```

### Diagram 2: Traffic Flow with Both Load Balancers

```
External Client (10.1.1.5)
         │
         │ Request: GET http://grafana.homelab.local
         │ (DNS resolves to 10.1.1.100)
         │
         ↓
╔════════════════════════════════════════════════════════════╗
║              LAYER 4: MetalLB (L2 Mode)                    ║
║                                                            ║
║  1. Client sends: Dest IP=10.1.1.100, Port=80             ║
║  2. ARP: "Who has 10.1.1.100?"                            ║
║  3. MetalLB Speaker responds with node MAC                 ║
║  4. Traffic forwarded to Worker-1 (10.1.1.31)             ║
║  5. kube-proxy sends to Traefik pod (any node)            ║
║                                                            ║
║  Knows: IP addresses, Ports, TCP/UDP                       ║
║  Does NOT know: HTTP headers, paths, hosts                 ║
╚════════════════════════════════════════════════════════════╝
         │
         │ TCP connection established
         │ Packet delivered to Traefik pod
         │
         ↓
╔════════════════════════════════════════════════════════════╗
║              LAYER 7: Traefik Ingress                      ║
║                                                            ║
║  1. Terminates TCP connection                              ║
║  2. Parses HTTP request:                                   ║
║     ┌──────────────────────────────────────┐              ║
║     │ GET / HTTP/1.1                       │              ║
║     │ Host: grafana.homelab.local          │ ← Reads this!║
║     │ User-Agent: Mozilla/5.0              │              ║
║     └──────────────────────────────────────┘              ║
║  3. Matches Ingress rule:                                  ║
║     Host: grafana.homelab.local                            ║
║       → backend: kube-prometheus-stack-grafana:80         ║
║  4. Load balances across Grafana pod replicas              ║
║  5. Proxies request to selected pod                        ║
║                                                            ║
║  Knows: Everything (headers, paths, cookies, methods)      ║
╚════════════════════════════════════════════════════════════╝
         │
         │ HTTP request proxied
         │
         ↓
    ┌──────────────────────┐
    │ Kubernetes Service   │
    │ grafana:80           │
    │ (ClusterIP)          │
    └──────────┬───────────┘
               │
               ↓
         ┌──────────┐
         │ Grafana  │
         │   Pod    │
         │          │
         └──────────┘
```

### Diagram 3: MetalLB Components

```
┌─────────────────────────────────────────────────────────────┐
│                    metallb-system Namespace                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────────────────────────────────────────┐     │
│  │             MetalLB Controller                    │     │
│  │              (Deployment)                         │     │
│  │                                                   │     │
│  │  Responsibilities:                                │     │
│  │  • Watch for new LoadBalancer services           │     │
│  │  • Assign IPs from configured pools              │     │
│  │  • Update service status with EXTERNAL-IP         │     │
│  │  • Coordinate with speakers                      │     │
│  │                                                   │     │
│  │  IPAddressPool:                                   │     │
│  │    10.1.1.100-10.1.1.150 (51 IPs)                │     │
│  │                                                   │     │
│  │  Next available IP: 10.1.1.101                    │     │
│  └───────────────┬───────────────────────────────────┘     │
│                  │ Assigns IP                              │
│                  ↓                                         │
│  ┌─────────────────────────────────────────────────────┐   │
│  │        LoadBalancer Service: traefik              │   │
│  │        EXTERNAL-IP: 10.1.1.100                    │   │
│  └─────────────────────────────────────────────────────┘   │
│                  │                                         │
│                  │ Announces to speakers                   │
│                  ↓                                         │
│  ┌────────────────────────────────────────────────────┐    │
│  │           MetalLB Speakers                        │    │
│  │            (DaemonSet)                            │    │
│  │                                                   │    │
│  │  Runs on EVERY node in cluster:                  │    │
│  │                                                   │    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐          │    │
│  │  │Master-1 │  │Worker-1 │  │Worker-2 │  ...     │    │
│  │  │Speaker  │  │Speaker  │  │Speaker  │          │    │
│  │  │         │  │ [LEADER]│  │         │          │    │
│  │  └─────────┘  └────┬────┘  └─────────┘          │    │
│  │                    │                             │    │
│  │  L2Advertisement:  │                             │    │
│  │  - homelab-pool    │                             │    │
│  │                    │                             │    │
│  │  Leader Election:  ↓                             │    │
│  │  Worker-1 is leader for 10.1.1.100               │    │
│  │  Responds to ARP requests                        │    │
│  │  "10.1.1.100 is at MAC: Worker-1's MAC"          │    │
│  └───────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Diagram 4: Request Flow Example

```
Scenario: Three different applications behind one IP

┌──────────────────────────────────────────────────────────┐
│                External Clients                          │
└────┬────────────────┬────────────────┬──────────────────┘
     │                │                │
     │ Request A:     │ Request B:     │ Request C:
     │ grafana.home   │ prom.home      │ app.home/api
     │                │                │
     └────────┬───────┴────────┬───────┘
              │                │
              │ All resolve to same IP: 10.1.1.100
              │
              ↓
    ┌──────────────────────────┐
    │  MetalLB (Layer 4)       │  Destination: 10.1.1.100:80
    │  "Just forward TCP to    │  MetalLB: "I don't care about
    │   any Traefik pod"       │           Host headers"
    └──────────┬───────────────┘
               │
               ↓
    ┌──────────────────────────────────────────────────────┐
    │           Traefik (Layer 7)                          │
    │                                                      │
    │  ┌─────────────────────────────────────────────┐    │
    │  │ Routing Logic:                              │    │
    │  │                                             │    │
    │  │ IF Host == "grafana.home"                   │    │
    │  │   → backend: grafana-service:3000           │    │
    │  │                                             │    │
    │  │ ELSE IF Host == "prom.home"                 │    │
    │  │   → backend: prometheus-service:9090        │    │
    │  │                                             │    │
    │  │ ELSE IF Host == "app.home" AND Path == "/api"   │
    │  │   → backend: api-service:8080               │    │
    │  │                                             │    │
    │  │ ELSE                                        │    │
    │  │   → 404 Not Found                           │    │
    │  └─────────────────────────────────────────────┘    │
    └──────────┬──────────┬──────────┬────────────────────┘
               │          │          │
               ↓          ↓          ↓
         ┌─────────┐ ┌──────────┐ ┌─────────┐
         │ Grafana │ │Prometheus│ │   API   │
         │ Pods    │ │  Pods    │ │  Pods   │
         └─────────┘ └──────────┘ └─────────┘
```

---

## Key Differences Summary

| Aspect | MetalLB (Layer 4) | Traefik (Layer 7) |
|--------|-------------------|-------------------|
| **OSI Layer** | Transport (L4) + Data Link (L2) | Application (L7) |
| **What it sees** | IP, Port, Protocol | HTTP headers, paths, cookies |
| **Routing logic** | IP:Port → Service | Host, Path, Headers → Backend |
| **Protocol** | Any TCP/UDP | HTTP/HTTPS |
| **Speed** | Very fast (packet forwarding) | Slower (HTTP parsing) |
| **SSL termination** | No | Yes |
| **Content routing** | No | Yes |
| **Use case** | External IP assignment | HTTP/HTTPS routing |
| **Cloud equivalent** | AWS Network LB, GCP TCP/UDP LB | AWS ALB, GCP HTTP(S) LB |

---

## Current Deployment Status

### MetalLB Configuration
```bash
# IP Pool
kubectl get ipaddresspool -n metallb-system
# NAME           AUTO ASSIGN   ADDRESSES
# homelab-pool   true          10.1.1.100-10.1.1.150

# L2 Advertisement
kubectl get l2advertisement -n metallb-system
# NAME          IPADDRESSPOOLS
# homelab-l2    ["homelab-pool"]
```

### Traefik Configuration
```bash
# Traefik Service (gets IP from MetalLB)
kubectl get svc -n traefik traefik
# NAME      TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)
# traefik   LoadBalancer   10.100.39.20   10.1.1.100    80:32732/TCP,443:32171/TCP

# Traefik Dashboard (NodePort)
kubectl get svc -n traefik traefik-dashboard
# NAME                TYPE       PORT(S)
# traefik-dashboard   NodePort   8080:30008/TCP

# Access dashboard at: http://any-node-ip:30008
```

### Access Points
```
Traefik LoadBalancer:  http://10.1.1.100
Traefik Dashboard:     http://10.1.1.11:30008 (any node IP)
Grafana (existing):    http://10.1.1.11:30000
```

---

## Testing the Setup

### 1. Create a Test Application

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: test-app
  namespace: default
spec:
  selector:
    app: test-app
  ports:
  - port: 80
    targetPort: 80

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-app
  namespace: default
spec:
  ingressClassName: traefik
  rules:
  - host: test.homelab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: test-app
            port:
              number: 80
```

### 2. Test Access

```bash
# Add to /etc/hosts on your client machine
echo "10.1.1.100 test.homelab.local" | sudo tee -a /etc/hosts

# Test HTTP access
curl http://test.homelab.local
# Should return nginx welcome page

# Verify Traefik routing
curl -H "Host: test.homelab.local" http://10.1.1.100
```

---

## Conclusion

Your homelab now has a **two-tier load balancing architecture**:

1. **MetalLB (Layer 4)**: Provides external IPs to Kubernetes services using L2/ARP
2. **Traefik (Layer 7)**: Routes HTTP/HTTPS traffic based on hostnames and paths

This is the same architecture used in production cloud environments:
- **Cloud**: AWS NLB (L4) → AWS ALB (L7)
- **Homelab**: MetalLB (L4) → Traefik (L7)

The combination gives you the best of both worlds:
- MetalLB handles network-level load balancing and IP assignment
- Traefik handles application-level routing with content awareness
