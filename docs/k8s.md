# Kubernetes Configuration Guide

This guide covers the setup and configuration of a Kubernetes cluster in the homelab environment.

## Prerequisites

- Ubuntu Server 22.04 LTS or later
- Minimum 2 CPU cores
- Minimum 2GB RAM
- Network connectivity between nodes
- Swap disabled on all nodes

## Initial Setup

### 1. Initialize the Control Plane

Initialize the first master node with the following command:

```bash
sudo kubeadm init \
  --control-plane-endpoint=10.10.10.1 \
  --node-name controller \
  --pod-network-cidr=10.244.0.0/16
```

### 2. Configure kubectl Access

After successful initialization, configure kubectl for your user:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

For root user:
```bash
export KUBECONFIG=/etc/kubernetes/admin.conf
```

### 3. Deploy Pod Network

Install a CNI (Container Network Interface) plugin. For example, using Flannel:

```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

## Joining Nodes

### Control Plane Nodes

To add additional control plane nodes, first copy the certificates and then run:

```bash
kubeadm join 10.10.10.1:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane
```

### Worker Nodes

To join worker nodes to the cluster:

```bash
kubeadm join 10.10.10.1:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

> **Note**: Tokens expire after 24 hours. Generate a new token with:
> ```bash
> kubeadm token create --print-join-command
> ```

## Network Configuration

### Static IP Configuration

Example Netplan configuration (`/etc/netplan/50-cloud-init.yaml`):

```yaml
network:
  version: 2
  ethernets:
    eth0:
      addresses: [10.10.10.3/8]
      nameservers:
        addresses: [10.0.0.1]
      routes:
        - to: default
          via: 10.0.0.1
```

Apply network configuration:
```bash
sudo netplan apply
```

## Load Balancer Setup (MetalLB)

### Installation

Deploy MetalLB for bare metal load balancer support:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
```

### Configuration

Create an IP address pool configuration:

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.10.10.200-10.10.10.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advert
  namespace: metallb-system
```

### Troubleshooting MetalLB

If you encounter webhook errors during configuration:

1. Check MetalLB pods and services:
```bash
kubectl get pods,svc -n metallb-system
```

2. Ensure webhook service is running:
```bash
kubectl describe svc metallb-webhook-service -n metallb-system
```

3. Check pod logs for errors:
```bash
kubectl logs -n metallb-system deployment/metallb-controller
```

## Cluster Management

### Check Cluster Status

```bash
# View nodes
kubectl get nodes

# View all pods across namespaces
kubectl get pods --all-namespaces

# View cluster info
kubectl cluster-info

# Check component status
kubectl get componentstatuses
```

### Common Issues and Solutions

#### Issue: No Route to Host for Services

**Symptoms**: Services unreachable, webhook errors

**Solution**:
1. Check kube-proxy is running:
```bash
kubectl get pods -n kube-system | grep kube-proxy
```

2. Verify iptables rules:
```bash
sudo iptables -L -n -t nat | grep KUBE
```

3. Restart kube-proxy if needed:
```bash
kubectl rollout restart daemonset kube-proxy -n kube-system
```

#### Issue: CoreDNS Not Resolving

**Symptoms**: DNS resolution failures within pods

**Solution**:
1. Check CoreDNS pods:
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

2. Review CoreDNS logs:
```bash
kubectl logs -n kube-system -l k8s-app=kube-dns
```

3. Restart CoreDNS if needed:
```bash
kubectl rollout restart deployment coredns -n kube-system
```

## Security Considerations

- Always use TLS certificates for API server communication
- Implement RBAC (Role-Based Access Control)
- Regular certificate rotation
- Network policies for pod-to-pod communication
- Keep Kubernetes components updated

## Backup and Recovery

### Backup ETCD

```bash
ETCDCTL_API=3 etcdctl snapshot save backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

### Restore ETCD

```bash
ETCDCTL_API=3 etcdctl snapshot restore backup.db \
  --data-dir=/var/lib/etcd-backup
```

## Monitoring

Consider deploying monitoring solutions:
- Prometheus for metrics collection
- Grafana for visualization
- Alert Manager for alerting

## Additional Resources

- [Official Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kubernetes Network Concepts](https://kubernetes.io/docs/concepts/cluster-administration/networking/)
- [MetalLB Documentation](https://metallb.universe.tf/)
- [Kubeadm Documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)