#!/bin/bash

# Comprehensive Monitoring Stack Deployment with Enhanced Grafana
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

log "🚀 Deploying comprehensive monitoring stack with enhanced Grafana..."

# Create monitoring namespace
log "Creating monitoring namespace..."
kubectl create namespace monitoring || true

# Deploy Prometheus Operator
log "Deploying Prometheus Operator..."
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.68.0/bundle.yaml

# Wait for operator to be ready
log "Waiting for Prometheus Operator to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/prometheus-operator -n default

# Create Prometheus RBAC
log "Creating Prometheus RBAC..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - nodes/metrics
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups:
  - extensions
  resources:
  - ingresses
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: monitoring
EOF

# Deploy Prometheus instance
log "Deploying Prometheus..."
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: prometheus
  namespace: monitoring
spec:
  serviceAccountName: prometheus
  serviceMonitorSelector:
    matchLabels:
      team: frontend
  ruleSelector:
    matchLabels:
      team: frontend
      role: alert-rules
  resources:
    requests:
      memory: 400Mi
      cpu: 100m
    limits:
      memory: 2Gi
      cpu: 1000m
  retention: 30d
  storage:
    volumeClaimTemplate:
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 50Gi
  enableAdminAPI: true
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus-service
  namespace: monitoring
spec:
  type: NodePort
  ports:
  - name: web
    nodePort: 30900
    port: 9090
    protocol: TCP
    targetPort: web
  selector:
    prometheus: prometheus
EOF

# Deploy Grafana with enhanced configuration
log "Deploying Grafana with comprehensive dashboards..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: monitoring
data:
  prometheus.yaml: |-
    {
        "apiVersion": 1,
        "datasources": [
            {
                "access": "proxy",
                "editable": true,
                "name": "prometheus",
                "orgId": 1,
                "type": "prometheus",
                "url": "http://prometheus-service:9090",
                "version": 1
            }
        ]
    }
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards-config
  namespace: monitoring
data:
  dashboards.yaml: |-
    apiVersion: 1
    providers:
    - name: 'default'
      orgId: 1
      folder: ''
      type: file
      disableDeletion: false
      updateIntervalSeconds: 30
      options:
        path: /var/lib/grafana/dashboards
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: homelab-dashboard
  namespace: monitoring
data:
  homelab-overview.json: |-
    {
      "dashboard": {
        "id": null,
        "title": "HomeLab Infrastructure Overview",
        "tags": ["homelab", "infrastructure"],
        "style": "dark",
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Cluster Overview",
            "type": "stat",
            "targets": [
              {
                "expr": "up",
                "refId": "A"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "color": {
                  "mode": "palette-classic"
                },
                "custom": {
                  "displayMode": "list",
                  "orientation": "auto"
                }
              }
            },
            "options": {
              "reduceOptions": {
                "values": false,
                "calcs": ["lastNotNull"],
                "fields": ""
              },
              "orientation": "auto",
              "textMode": "auto",
              "colorMode": "value",
              "graphMode": "area",
              "justifyMode": "auto"
            },
            "pluginVersion": "8.0.0",
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
          }
        ],
        "time": {"from": "now-1h", "to": "now"},
        "refresh": "5s"
      }
    }
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
      securityContext:
        fsGroup: 472
        supplementalGroups:
        - 0
      containers:
      - name: grafana
        image: grafana/grafana:10.1.0
        ports:
        - containerPort: 3000
          name: http-grafana
          protocol: TCP
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /robots.txt
            port: 3000
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 30
          successThreshold: 1
          timeoutSeconds: 2
        livenessProbe:
          failureThreshold: 3
          initialDelaySeconds: 30
          periodSeconds: 10
          successThreshold: 1
          tcpSocket:
            port: 3000
          timeoutSeconds: 1
        resources:
          requests:
            cpu: 250m
            memory: 750Mi
        volumeMounts:
        - mountPath: /var/lib/grafana
          name: grafana-pv
        - mountPath: /etc/grafana/provisioning/datasources
          name: grafana-datasources
          readOnly: false
        - mountPath: /etc/grafana/provisioning/dashboards
          name: grafana-dashboards-config
          readOnly: false
        - mountPath: /var/lib/grafana/dashboards
          name: grafana-dashboards
          readOnly: false
        env:
        - name: GF_SECURITY_ADMIN_USER
          value: admin
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: admin123
        - name: GF_INSTALL_PLUGINS
          value: "grafana-kubernetes-app,grafana-worldmap-panel,grafana-piechart-panel"
      volumes:
      - name: grafana-pv
        emptyDir: {}
      - name: grafana-datasources
        configMap:
          defaultMode: 420
          name: grafana-datasources
      - name: grafana-dashboards-config
        configMap:
          defaultMode: 420
          name: grafana-dashboards-config
      - name: grafana-dashboards
        configMap:
          defaultMode: 420
          name: homelab-dashboard
---
apiVersion: v1
kind: Service
metadata:
  name: grafana-service
  namespace: monitoring
spec:
  ports:
  - port: 3000
    protocol: TCP
    targetPort: http-grafana
    nodePort: 30300
  selector:
    app: grafana
  type: NodePort
EOF

# Deploy Node Exporter for system metrics
log "Deploying Node Exporter..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: monitoring
  labels:
    app.kubernetes.io/component: exporter
    app.kubernetes.io/name: node-exporter
spec:
  selector:
    matchLabels:
      app.kubernetes.io/component: exporter
      app.kubernetes.io/name: node-exporter
  template:
    metadata:
      labels:
        app.kubernetes.io/component: exporter
        app.kubernetes.io/name: node-exporter
    spec:
      containers:
      - args:
        - --path.sysfs=/host/sys
        - --path.rootfs=/host/root
        - --no-collector.wifi
        - --no-collector.hwmon
        - --collector.filesystem.ignored-mount-points=^/(dev|proc|sys|var/lib/docker/.+|var/lib/kubelet/pods/.+)(\$|/)
        - --collector.netclass.ignored-devices=^(veth.*|[a-f0-9]{15})
        - --collector.netdev.device-exclude=^(veth.*|[a-f0-9]{15})
        name: node-exporter
        image: prom/node-exporter
        ports:
        - containerPort: 9100
          protocol: TCP
        resources:
          limits:
            cpu: 250m
            memory: 180Mi
          requests:
            cpu: 102m
            memory: 180Mi
        volumeMounts:
        - mountPath: /host/sys
          mountPropagation: HostToContainer
          name: sys
          readOnly: true
        - mountPath: /host/root
          mountPropagation: HostToContainer
          name: root
          readOnly: true
      volumes:
      - hostPath:
          path: /sys
        name: sys
      - hostPath:
          path: /
        name: root
      hostNetwork: true
      hostPID: true
---
apiVersion: v1
kind: Service
metadata:
  name: node-exporter-service
  namespace: monitoring
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9100"
spec:
  type: ClusterIP
  clusterIP: None
  selector:
    app.kubernetes.io/component: exporter
    app.kubernetes.io/name: node-exporter
  ports:
  - name: node-exporter
    port: 9100
    targetPort: 9100
EOF

# Create ServiceMonitor for Node Exporter
log "Creating ServiceMonitor for Node Exporter..."
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: node-exporter
  namespace: monitoring
  labels:
    team: frontend
spec:
  selector:
    matchLabels:
      app.kubernetes.io/component: exporter
      app.kubernetes.io/name: node-exporter
  endpoints:
  - port: node-exporter
EOF

# Wait for deployments
log "Waiting for monitoring stack to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n monitoring

log "✅ Monitoring stack deployed successfully!"
log "🌟 Grafana Dashboard: http://<node-ip>:30300 (admin/admin123)"
log "📊 Prometheus: http://<node-ip>:30900"
log "💡 Enhanced Grafana with homelab-specific dashboards is ready!"