# Troubleshooting: IPv6 Docker Hub Connection Issues

## Issue
Pods failing with `ImagePullBackOff` or `ErrImagePull` when pulling images from Docker Hub (docker.io).

## Symptoms
```
$ kubectl get pods -A | grep ImagePull
longhorn-system      longhorn-manager-xxx    0/2     ImagePullBackOff
```

Pod events show:
```
Failed to pull image "busybox": failed to pull and unpack image "docker.io/library/busybox:latest":
failed to resolve reference: Head "https://registry-1.docker.io/v2/...": net/http: TLS handshake timeout
```

## Root Cause
The cluster nodes prefer IPv6 when connecting to Docker Hub's registry (`registry-1.docker.io`). While DNS resolution works and TCP connections are established via IPv6, the TLS handshake times out.

Docker Hub's IPv6 endpoints appear to have connectivity issues, while IPv4 works correctly.

## Diagnosis

### 1. Verify DNS resolution works
```bash
nslookup registry-1.docker.io
```

### 2. Test IPv6 vs IPv4 connectivity
```bash
# IPv6 - times out
curl -v --connect-timeout 15 https://registry-1.docker.io/v2/

# IPv4 - works
curl -4 -I --connect-timeout 15 https://registry-1.docker.io/v2/
```

### 3. Check if other registries work
```bash
# GHCR works (uses different infrastructure)
curl -I https://ghcr.io/v2/
```

## Solution

Block IPv6 traffic to Docker Hub at the router level, forcing clients to fall back to IPv4.

### MikroTik Router Configuration
```routeros
/ipv6 firewall filter add \
  chain=forward \
  action=reject \
  reject-with=icmp-address-unreachable \
  dst-address=2600:1f18::/32 \
  protocol=tcp \
  dst-port=443 \
  comment="Block Docker Hub IPv6 - forces IPv4 fallback" \
  place-before=0
```

This rule:
1. Blocks IPv6 connections to Docker Hub's address range (2600:1f18::/32)
2. Rejects with ICMP unreachable, causing immediate fallback to IPv4
3. Applies to all devices on the network automatically

### Restart affected pods
```bash
# Delete pods with ImagePullBackOff to trigger retry
kubectl get pods -A --no-headers | awk '/ImagePull|ErrImage/ {print "-n", $1, $2}' | xargs kubectl delete pod
```

## Prevention

The MikroTik firewall rule should be configured as part of network setup to prevent this issue for all cluster nodes.

## Notes

- Router-level fix is preferred over per-node fixes (gai.conf, sysctl) as it applies automatically to all nodes
- The IPv6 block is specific to Docker Hub and doesn't affect other IPv6 traffic
- Other registries (ghcr.io, quay.io) work fine with IPv6
