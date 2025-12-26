#!/bin/bash

# Simple Grafana Deployment with Essential Dashboards
set -e

GREEN='\033[0;32m'
NC='\033[0m'
log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }

log "🚀 Deploying Grafana monitoring stack..."

# Deploy simple Prometheus
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus
        args:
        - '--config.file=/etc/prometheus/prometheus.yml'
        - '--storage.tsdb.path=/prometheus'
        - '--web.console.libraries=/etc/prometheus/console_libraries'
        - '--web.console.templates=/etc/prometheus/consoles'
        - '--web.enable-lifecycle'
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus-service
  namespace: monitoring
spec:
  type: NodePort
  ports:
  - port: 9090
    targetPort: 9090
    nodePort: 30900
  selector:
    app: prometheus
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "admin123"
        volumeMounts:
        - name: grafana-datasources
          mountPath: /etc/grafana/provisioning/datasources
        - name: grafana-dashboards
          mountPath: /etc/grafana/provisioning/dashboards
        - name: dashboard-files
          mountPath: /var/lib/grafana/dashboards
      volumes:
      - name: grafana-datasources
        configMap:
          name: grafana-datasources
      - name: grafana-dashboards
        configMap:
          name: grafana-dashboards
      - name: dashboard-files
        configMap:
          name: dashboard-files
---
apiVersion: v1
kind: Service
metadata:
  name: grafana-service
  namespace: monitoring
spec:
  type: NodePort
  ports:
  - port: 3000
    targetPort: 3000
    nodePort: 30300
  selector:
    app: grafana
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: monitoring
data:
  datasource.yml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      access: proxy
      url: http://prometheus-service:9090
      isDefault: true
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards
  namespace: monitoring
data:
  dashboard.yml: |
    apiVersion: 1
    providers:
    - name: 'default'
      orgId: 1
      folder: 'HomeLab'
      type: file
      disableDeletion: false
      updateIntervalSeconds: 30
      allowUiUpdates: true
      options:
        path: /var/lib/grafana/dashboards
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: dashboard-files
  namespace: monitoring
data:
  homelab-overview.json: |
    {
      "dashboard": {
        "id": null,
        "title": "HomeLab Infrastructure Overview - Dark Knight Edition",
        "tags": ["homelab", "infrastructure", "dark-knight"],
        "style": "dark",
        "theme": "dark",
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Cluster Status",
            "type": "stat",
            "targets": [
              {
                "expr": "up",
                "refId": "A",
                "legendFormat": "{{instance}}"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "color": {
                  "mode": "palette-classic"
                },
                "mappings": [],
                "thresholds": {
                  "steps": [
                    {
                      "color": "red",
                      "value": null
                    },
                    {
                      "color": "green",
                      "value": 1
                    }
                  ]
                }
              }
            },
            "options": {
              "colorMode": "background",
              "graphMode": "area",
              "justifyMode": "center",
              "orientation": "horizontal",
              "reduceOptions": {
                "calcs": ["lastNotNull"],
                "fields": "",
                "values": false
              },
              "textMode": "auto"
            },
            "pluginVersion": "8.0.0",
            "gridPos": {"h": 8, "w": 24, "x": 0, "y": 0}
          }
        ],
        "time": {"from": "now-1h", "to": "now"},
        "refresh": "5s"
      }
    }
EOF

log "✅ Grafana monitoring stack deployed!"
log "🌟 Access Grafana at: http://<node-ip>:30300 (admin/admin123)"
log "📊 Access Prometheus at: http://<node-ip>:30900"