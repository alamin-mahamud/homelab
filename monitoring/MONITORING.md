# Homelab Monitoring Stack

Comprehensive monitoring solution for Kubernetes cluster, nodes, and network infrastructure.

## Stack Components

### Deployed Services

| Service | Port | Purpose |
|---------|------|---------|
| Grafana | 30000 | Visualization dashboards |
| Prometheus | 9090 | Metrics collection |
| Alertmanager | 30001 | Alert management |
| Loki | 3100 | Log aggregation |

## Access Grafana

### Via NodePort (Any K8s Node)

```bash
# Access from any of these IPs on port 30000:
http://10.1.1.11:30000  # master-01
http://10.1.1.31:30000  # worker-01
http://10.1.1.60:30000  # pi-worker-01

# Default credentials:
Username: admin
Password: admin123
```

### Get Grafana Password

```bash
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d
```

## What's Being Monitored

###  **Kubernetes Cluster**
- API server metrics
- Controller manager metrics
- Scheduler metrics
- etcd cluster health
- Pod/Container resource usage
- Cluster events

### **All Nodes (15 nodes)**
- CPU usage, load average
- Memory usage
- Disk I/O, space
- Network traffic
- System uptime

### **Logs (via Loki)**
- All pod logs
- System logs
- Application logs
- 30-day retention

## Pre-configured Dashboards

Grafana includes 20+ dashboards:

1. **Kubernetes / Compute Resources / Cluster**
2. **Kubernetes / Compute Resources / Namespace (Pods)**
3. **Kubernetes / Networking / Cluster**
4. **Node Exporter / Nodes** - Individual node metrics
5. **Prometheus / Overview**
6. **AlertManager / Overview**

## Configure Loki in Grafana

1. Login to Grafana (http://NODE_IP:30000)
2. Go to Configuration → Data Sources
3. Add Loki:
   - URL: `http://loki.monitoring:3100`
   - Save & Test

## Mikrotik Router Monitoring

### SNMP is Enabled and Working! ✓

The SNMP exporter is successfully collecting metrics from your Mikrotik router (10.0.0.1).

**Detected Interfaces:**
- ether1-5 (Physical interfaces)
- bridge (defconf)
- DOT
- MAZEDA

### View Mikrotik Metrics in Grafana

**Option 1: Import Pre-made Dashboard**

1. Open Grafana: http://10.1.1.31:30000
2. Login (admin/admin123)
3. Go to **Dashboards** → **Import**
4. Click **Upload JSON file**
5. Select: `/home/ubuntu/src/homelab/monitoring/mikrotik-dashboard.json`
6. Click **Import**

This dashboard shows:
- Interface traffic rates (bits/sec)
- Total traffic counters
- Interface status table

**Option 2: Explore Metrics Manually**

1. Go to **Explore** in Grafana
2. Select **Prometheus** datasource
3. Try these queries:

```promql
# Interface traffic IN (bits per second)
rate(ifHCInOctets{job="mikrotik-router"}[5m]) * 8

# Interface traffic OUT (bits per second)
rate(ifHCOutOctets{job="mikrotik-router"}[5m]) * 8

# Total bytes received per interface
ifHCInOctets{job="mikrotik-router"}

# Interface operational status (1=up, 2=down)
ifOperStatus{job="mikrotik-router"}
```

**Option 3: Use Community Dashboard**

1. Go to **Dashboards** → **Import**
2. Use dashboard ID: **11169** (SNMP Interface Throughput)
3. Select Prometheus as datasource
4. Click Import

### Monitored Metrics

- **Interface traffic**: Upload/download rates and totals
- **Interface status**: Operational and admin status
- **Packet counters**: Unicast, broadcast, multicast
- **Error counters**: Discards, errors
- **Bandwidth utilization**: Per interface

## View Metrics

### Prometheus Targets

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Open: http://localhost:9090/targets
```

### Query Metrics

```promql
# Node CPU usage
node_cpu_seconds_total

# Pod memory usage
container_memory_usage_bytes

# Network traffic
node_network_receive_bytes_total
```

## Alerting

Alertmanager is configured for:
- High CPU/Memory usage
- Pod restarts
- Node down
- Disk space warnings

Edit alertmanager config:
```bash
kubectl edit alertmanagerconfig -n monitoring
```

## Storage

- Prometheus: 50GB retention (30 days)
- Grafana: 10GB for dashboards/config
- Loki: 10GB for logs (30 days)

## Useful Commands

```bash
# Check all monitoring pods
kubectl get pods -n monitoring

# View Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

# View Prometheus logs
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0

# Restart Grafana
kubectl rollout restart deployment/kube-prometheus-stack-grafana -n monitoring
```

## Troubleshooting

### Grafana not accessible

```bash
kubectl get svc -n monitoring kube-prometheus-stack-grafana
kubectl describe pod -n monitoring -l app.kubernetes.io/name=grafana
```

### Missing metrics

```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit: http://localhost:9090/targets
```

### Logs not showing in Loki

```bash
# Check Promtail status
kubectl get pods -n monitoring -l app=promtail
kubectl logs -n monitoring -l app=promtail
```

## Next Steps

1. **Import Community Dashboards**
   - Dashboard ID 1860: Node Exporter Full
   - Dashboard ID 315: Kubernetes cluster monitoring
   - Dashboard ID 747: Kubernetes Deployment Statefulset

2. **Setup Alerts**
   - Configure Slack/Email notifications
   - Create custom alert rules

3. **Add Custom Metrics**
   - Application-specific exporters
   - Custom Prometheus metrics
