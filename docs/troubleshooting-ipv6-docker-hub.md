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

Configure system-wide IPv4 preference via `/etc/gai.conf` on all nodes.

### Deploy IPv4 Preference DaemonSet
```bash
kubectl apply -f k8s/system/ipv4-preference.yaml
```

This DaemonSet:
1. Runs on all nodes (including control plane)
2. Writes `precedence ::ffff:0:0/96  100` to `/etc/gai.conf`
3. Makes the system prefer IPv4 over IPv6 for DNS resolution

### Restart affected pods
```bash
# Delete pods with ImagePullBackOff to trigger retry
kubectl get pods -A --no-headers | grep -e ImagePull -e ErrImage | \
  awk '{print "-n", $1, $2}' | xargs -r kubectl delete pod
```

### For persistent issues, restart containerd on affected nodes
The gai.conf change only affects new processes. If containerd has cached DNS results:

```bash
# Via privileged pod
kubectl run restart-containerd --rm -it --restart=Never \
  --overrides='{"spec":{"nodeName":"NODE_NAME","hostPID":true,...}}' \
  -- nsenter --target 1 --mount --pid -- systemctl restart containerd
```

## Prevention

The `k8s/system/ipv4-preference.yaml` DaemonSet should be deployed as part of cluster setup to prevent this issue.

## Related Files
- `k8s/system/ipv4-preference.yaml` - DaemonSet to set IPv4 preference
