# Traefik Service Routing Guide

This guide explains how to expose services through Traefik with domain-based routing.

## Overview

You have two Traefik deployments:
1. **Kubernetes Traefik** - Running in the `traefik` namespace
2. **Docker Compose Traefik** - Running as a container

## DNS Configuration

First, configure your DNS (Pi-hole or /etc/hosts) to point domains to your Traefik instance:

```bash
# Add to Pi-hole or /etc/hosts
10.2.0.100    grafana.homelab.local
10.2.0.100    prometheus.homelab.local
10.2.0.100    portainer.homelab.local
10.2.0.100    nextcloud.homelab.local
```

Replace `10.2.0.100` with your Traefik LoadBalancer IP (from MetalLB).

To find your Traefik LoadBalancer IP:
```bash
kubectl get svc -n traefik traefik
```

## Kubernetes Services

### Method 1: IngressRoute (Traefik CRD) - Recommended

Create an IngressRoute for each service:

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: grafana
  namespace: monitoring
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`grafana.homelab.local`)
      kind: Rule
      services:
        - name: kube-prometheus-stack-grafana
          port: 80
```

Apply it:
```bash
kubectl apply -f monitoring/grafana-ingress.yaml
```

### Method 2: Standard Kubernetes Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
    - host: grafana.homelab.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kube-prometheus-stack-grafana
                port:
                  number: 80
```

## Docker Compose Services

For Docker Compose services, add Traefik labels:

```yaml
services:
  nextcloud:
    image: nextcloud:latest
    networks:
      - homelab-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.nextcloud.rule=Host(`nextcloud.homelab.local`)"
      - "traefik.http.routers.nextcloud.entrypoints=web"
      - "traefik.http.services.nextcloud.loadbalancer.server.port=80"
      # Optional: HTTPS
      - "traefik.http.routers.nextcloud-secure.rule=Host(`nextcloud.homelab.local`)"
      - "traefik.http.routers.nextcloud-secure.entrypoints=websecure"
      - "traefik.http.routers.nextcloud-secure.tls=true"
```

## Common Patterns

### 1. Basic Service Exposure

**Kubernetes:**
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: service-name
  namespace: namespace
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`service.homelab.local`)
      kind: Rule
      services:
        - name: service-name
          port: 8080
```

**Docker Compose:**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.service.rule=Host(`service.homelab.local`)"
  - "traefik.http.services.service.loadbalancer.server.port=8080"
```

### 2. Path-based Routing

**Kubernetes:**
```yaml
routes:
  - match: Host(`app.homelab.local`) && PathPrefix(`/api`)
    kind: Rule
    services:
      - name: api-service
        port: 8080
  - match: Host(`app.homelab.local`) && PathPrefix(`/web`)
    kind: Rule
    services:
      - name: web-service
        port: 3000
```

**Docker Compose:**
```yaml
labels:
  - "traefik.http.routers.api.rule=Host(`app.homelab.local`) && PathPrefix(`/api`)"
  - "traefik.http.routers.web.rule=Host(`app.homelab.local`) && PathPrefix(`/web`)"
```

### 3. Middleware (Authentication, Headers, etc.)

**Kubernetes:**
```yaml
---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: auth
  namespace: default
spec:
  basicAuth:
    secret: auth-secret

---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: protected-service
spec:
  routes:
    - match: Host(`protected.homelab.local`)
      kind: Rule
      middlewares:
        - name: auth
      services:
        - name: protected-service
          port: 80
```

**Docker Compose:**
```yaml
labels:
  - "traefik.http.middlewares.auth.basicauth.users=admin:$$apr1$$H6... "
  - "traefik.http.routers.service.middlewares=auth"
```

### 4. HTTPS with TLS

**Kubernetes:**
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: service-secure
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`service.homelab.local`)
      kind: Rule
      services:
        - name: service
          port: 80
  tls:
    secretName: service-tls-cert
```

**Docker Compose:**
```yaml
labels:
  - "traefik.http.routers.service-secure.rule=Host(`service.homelab.local`)"
  - "traefik.http.routers.service-secure.entrypoints=websecure"
  - "traefik.http.routers.service-secure.tls=true"
```

## Quick Setup for Common Services

### Grafana (Kubernetes)
```bash
kubectl apply -f monitoring/grafana-ingress.yaml
```

### Prometheus (Kubernetes)
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: prometheus
  namespace: monitoring
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`prometheus.homelab.local`)
      kind: Rule
      services:
        - name: kube-prometheus-stack-prometheus
          port: 9090
```

### Portainer (Docker Compose)
Already in your docker-compose.yml, add labels:
```yaml
portainer:
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.portainer.rule=Host(`portainer.homelab.local`)"
    - "traefik.http.services.portainer.loadbalancer.server.port=9000"
```

## Traefik Dashboard Access

**Kubernetes:**
```bash
# Access via NodePort
http://<node-ip>:30008

# Or create IngressRoute
kubectl apply -f - <<EOF
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: traefik-dashboard
  namespace: traefik
spec:
  entryPoints:
    - web
  routes:
    - match: Host(\`traefik.homelab.local\`)
      kind: Rule
      services:
        - name: api@internal
          kind: TraefikService
EOF
```

**Docker Compose:**
```
http://<docker-host>:8082
```

## Troubleshooting

### 1. Check Traefik is running
```bash
# Kubernetes
kubectl get pods -n traefik
kubectl get svc -n traefik

# Docker
docker ps | grep traefik
```

### 2. Verify DNS resolution
```bash
nslookup grafana.homelab.local
ping grafana.homelab.local
```

### 3. Check IngressRoute status
```bash
kubectl get ingressroute -A
kubectl describe ingressroute grafana -n monitoring
```

### 4. View Traefik logs
```bash
# Kubernetes
kubectl logs -n traefik -l app=traefik

# Docker
docker logs traefik
```

### 5. Verify service is accessible
```bash
# Test from cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local

# Test from host
curl -H "Host: grafana.homelab.local" http://<traefik-ip>
```

## Next Steps

1. Create IngressRoutes for all your services
2. Set up proper DNS entries in Pi-hole
3. Configure TLS certificates (Let's Encrypt or self-signed)
4. Add authentication middleware for sensitive services
5. Monitor traffic through Traefik dashboard
