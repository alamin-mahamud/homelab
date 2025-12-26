# Whoami Installation Guide

## Overview

`whoami` is a simple HTTP server that displays information about incoming requests. It's perfect for:
- Testing Traefik ingress routing
- Debugging HTTP headers
- Verifying load balancing
- Learning Kubernetes service mesh behavior

## What It Does

When you access whoami, it displays:
- Container hostname (useful for seeing which pod served the request)
- HTTP request headers
- Client IP address
- Request method and path
- TLS information (if using HTTPS)

## Installation Steps

### 1. Deploy Whoami

```bash
kubectl apply -f /home/ubuntu/src/homelab/apps/whoami/whoami.yaml
```

This creates:
- Deployment with 2 replicas (for load balancing demonstration)
- ClusterIP Service
- Traefik IngressRoute

### 2. Verify Deployment

```bash
# Check pods are running
kubectl get pods -n infrastructure -l app=whoami

# Check service
kubectl get svc -n infrastructure whoami

# Check ingress route
kubectl get ingressroute -n infrastructure whoami
```

### 3. Add DNS Entry

Add to your `/etc/hosts` or Pi-hole:
```
10.1.1.100    whoami.homelab.local
```

### 4. Test Access

```bash
# Test from command line
curl http://whoami.homelab.local

# Or test via Traefik IP with Host header
curl -H "Host: whoami.homelab.local" http://10.1.1.100
```

Expected output:
```
Hostname: whoami-5df4d6c45c-7s8rg
IP: 127.0.0.1
IP: ::1
IP: 10.244.3.15
IP: fe80::d8e3:4dff:fe3a:e223
RemoteAddr: 10.244.8.18:44386
GET / HTTP/1.1
Host: whoami.homelab.local
User-Agent: curl/8.5.0
Accept: */*
Accept-Encoding: gzip
X-Forwarded-For: 10.244.8.20
X-Forwarded-Host: whoami.homelab.local
X-Forwarded-Port: 80
X-Forwarded-Proto: http
X-Forwarded-Server: traefik-6dd9f649dd-8lp7r
X-Real-Ip: 10.244.8.20
```

### 5. Test Load Balancing

Run multiple requests to see different hostnames (different pods):

```bash
# Run 10 requests
for i in {1..10}; do
  curl -s http://whoami.homelab.local | grep Hostname
done
```

You should see responses from both replicas alternating.

## Access via Browser

Open in your browser:
```
http://whoami.homelab.local
```

You'll see a formatted page showing all request details.

## Useful Test Scenarios

### 1. Test Custom Headers

```bash
curl -H "X-Custom-Header: test-value" http://whoami.homelab.local
```

### 2. Test Different Methods

```bash
# POST request
curl -X POST http://whoami.homelab.local

# PUT request with data
curl -X PUT -d "test=data" http://whoami.homelab.local
```

### 3. Test Path Routing

```bash
curl http://whoami.homelab.local/api/test
curl http://whoami.homelab.local/admin/dashboard
```

### 4. Monitor in Real-Time

```bash
# Watch logs from all whoami pods
kubectl logs -n infrastructure -l app=whoami -f
```

## Scaling Test

Scale up/down to test load balancing:

```bash
# Scale to 5 replicas
kubectl scale deployment -n infrastructure whoami --replicas=5

# Check pods
kubectl get pods -n infrastructure -l app=whoami

# Test load balancing across 5 pods
for i in {1..20}; do
  curl -s http://whoami.homelab.local | grep Hostname
done

# Scale back to 2
kubectl scale deployment -n infrastructure whoami --replicas=2
```

## Advanced: Path-Based Routing

Create an additional IngressRoute for path-based routing:

```yaml
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: whoami-api
  namespace: infrastructure
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`api.homelab.local`) && PathPrefix(`/whoami`)
      kind: Rule
      services:
        - name: whoami
          port: 80
```

Apply and test:
```bash
kubectl apply -f whoami-api-route.yaml
curl http://api.homelab.local/whoami
```

## Troubleshooting

### Pods Not Running

```bash
kubectl describe pod -n infrastructure -l app=whoami
kubectl logs -n infrastructure -l app=whoami
```

### Can't Access via Domain

```bash
# Test direct service access
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://whoami.infrastructure.svc.cluster.local

# Check IngressRoute
kubectl get ingressroute -n infrastructure whoami -o yaml

# Check Traefik logs
kubectl logs -n traefik -l app=traefik --tail=50 | grep whoami
```

### Not Load Balancing

```bash
# Verify multiple pods exist
kubectl get pods -n infrastructure -l app=whoami

# Check endpoints
kubectl get endpoints -n infrastructure whoami

# Verify service selector
kubectl get svc -n infrastructure whoami -o yaml
```

## Cleanup

When you're done testing:

```bash
kubectl delete -f /home/ubuntu/src/homelab/apps/whoami/whoami.yaml
```

## Integration with Other Services

### Test Middleware

Create middleware for authentication:

```yaml
---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: whoami-auth
  namespace: infrastructure
spec:
  basicAuth:
    secret: whoami-auth-secret

---
apiVersion: v1
kind: Secret
metadata:
  name: whoami-auth-secret
  namespace: infrastructure
type: Opaque
stringData:
  users: |
    admin:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/

---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: whoami-secure
  namespace: infrastructure
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`whoami-secure.homelab.local`)
      kind: Rule
      middlewares:
        - name: whoami-auth
      services:
        - name: whoami
          port: 80
```

Test with authentication:
```bash
# Without auth (will fail)
curl http://whoami-secure.homelab.local

# With auth (will succeed)
curl -u admin:admin http://whoami-secure.homelab.local
```

## Summary

Whoami is an excellent tool for:
- ✅ Verifying Traefik routing works
- ✅ Testing load balancing across replicas
- ✅ Debugging HTTP headers and proxying
- ✅ Learning Kubernetes networking
- ✅ Demonstrating ingress concepts

It's lightweight (32MB RAM) and safe to run alongside production services.
