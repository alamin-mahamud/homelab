#!/bin/bash

# Deploy Homelab Services to K8s Cluster
# This script deploys all homelab services as Kubernetes pods

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check kubectl is configured
if ! kubectl cluster-info &>/dev/null; then
    error "kubectl not configured. Please set up kubeconfig first."
fi

log "Starting Homelab services deployment to Kubernetes cluster"

# Create manifests directory
mkdir -p /home/ubuntu/src/homelab/deployment/k8s-manifests

# 1. Deploy Longhorn for distributed storage
log "Deploying Longhorn distributed storage..."
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.7.2/deploy/longhorn.yaml

# 2. Create Storage Classes
cat > /home/ubuntu/src/homelab/deployment/k8s-manifests/storage-classes.yaml <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-fast
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: driver.longhorn.io
parameters:
  numberOfReplicas: "2"
  staleReplicaTimeout: "30"
  fromBackup: ""
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

kubectl apply -f /home/ubuntu/src/homelab/deployment/k8s-manifests/storage-classes.yaml

# 3. Deploy Prometheus & Grafana Monitoring Stack
log "Deploying Prometheus and Grafana..."
cat > /home/ubuntu/src/homelab/deployment/k8s-manifests/monitoring-stack.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
---
# Prometheus ConfigMap
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
      - job_name: 'kubernetes-nodes'
        kubernetes_sd_configs:
          - role: node
        relabel_configs:
          - source_labels: [__address__]
            regex: '(.*):10250'
            replacement: '\${1}:9100'
            target_label: __address__
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
          - role: pod
---
# Prometheus Deployment
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
      serviceAccountName: prometheus
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: data
          mountPath: /prometheus
      volumes:
      - name: config
        configMap:
          name: prometheus-config
      - name: data
        persistentVolumeClaim:
          claimName: prometheus-pvc
---
# Prometheus Service
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  type: LoadBalancer
  selector:
    app: prometheus
  ports:
  - port: 9090
    targetPort: 9090
---
# Prometheus PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-pvc
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-fast
  resources:
    requests:
      storage: 50Gi
---
# Prometheus ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: monitoring
---
# Prometheus ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/metrics
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
---
# Prometheus ClusterRoleBinding
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
---
# Grafana Deployment
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
          value: "admin"
        volumeMounts:
        - name: data
          mountPath: /var/lib/grafana
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: grafana-pvc
---
# Grafana Service
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
spec:
  type: LoadBalancer
  selector:
    app: grafana
  ports:
  - port: 3000
    targetPort: 3000
---
# Grafana PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-pvc
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-fast
  resources:
    requests:
      storage: 10Gi
EOF

kubectl apply -f /home/ubuntu/src/homelab/deployment/k8s-manifests/monitoring-stack.yaml

# 4. Deploy Home Assistant
log "Deploying Home Assistant..."
cat > /home/ubuntu/src/homelab/deployment/k8s-manifests/home-assistant.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: homelab
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: home-assistant
  namespace: homelab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: home-assistant
  template:
    metadata:
      labels:
        app: home-assistant
    spec:
      hostNetwork: true
      containers:
      - name: home-assistant
        image: ghcr.io/home-assistant/home-assistant:stable
        ports:
        - containerPort: 8123
        volumeMounts:
        - name: config
          mountPath: /config
        - name: localtime
          mountPath: /etc/localtime
          readOnly: true
      volumes:
      - name: config
        persistentVolumeClaim:
          claimName: home-assistant-pvc
      - name: localtime
        hostPath:
          path: /etc/localtime
---
apiVersion: v1
kind: Service
metadata:
  name: home-assistant
  namespace: homelab
spec:
  type: LoadBalancer
  selector:
    app: home-assistant
  ports:
  - port: 8123
    targetPort: 8123
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: home-assistant-pvc
  namespace: homelab
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-fast
  resources:
    requests:
      storage: 10Gi
EOF

kubectl apply -f /home/ubuntu/src/homelab/deployment/k8s-manifests/home-assistant.yaml

# 5. Deploy Plex Media Server
log "Deploying Plex Media Server..."
cat > /home/ubuntu/src/homelab/deployment/k8s-manifests/plex.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: plex
  namespace: homelab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: plex
  template:
    metadata:
      labels:
        app: plex
    spec:
      containers:
      - name: plex
        image: linuxserver/plex:latest
        ports:
        - containerPort: 32400
        env:
        - name: PUID
          value: "1000"
        - name: PGID
          value: "1000"
        - name: VERSION
          value: "docker"
        - name: TZ
          value: "UTC"
        volumeMounts:
        - name: config
          mountPath: /config
        - name: media
          mountPath: /media
        resources:
          requests:
            cpu: "2"
            memory: "4Gi"
          limits:
            cpu: "4"
            memory: "8Gi"
      volumes:
      - name: config
        persistentVolumeClaim:
          claimName: plex-config-pvc
      - name: media
        persistentVolumeClaim:
          claimName: plex-media-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: plex
  namespace: homelab
spec:
  type: LoadBalancer
  selector:
    app: plex
  ports:
  - port: 32400
    targetPort: 32400
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: plex-config-pvc
  namespace: homelab
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-fast
  resources:
    requests:
      storage: 50Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: plex-media-pvc
  namespace: homelab
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-storage
  resources:
    requests:
      storage: 500Gi
EOF

kubectl apply -f /home/ubuntu/src/homelab/deployment/k8s-manifests/plex.yaml

# 6. Deploy Nextcloud
log "Deploying Nextcloud..."
cat > /home/ubuntu/src/homelab/deployment/k8s-manifests/nextcloud.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nextcloud
  namespace: homelab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nextcloud
  template:
    metadata:
      labels:
        app: nextcloud
    spec:
      containers:
      - name: nextcloud
        image: nextcloud:latest
        ports:
        - containerPort: 80
        env:
        - name: NEXTCLOUD_ADMIN_USER
          value: admin
        - name: NEXTCLOUD_ADMIN_PASSWORD
          value: admin123
        volumeMounts:
        - name: data
          mountPath: /var/www/html
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: nextcloud-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: nextcloud
  namespace: homelab
spec:
  type: LoadBalancer
  selector:
    app: nextcloud
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nextcloud-pvc
  namespace: homelab
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-fast
  resources:
    requests:
      storage: 100Gi
EOF

kubectl apply -f /home/ubuntu/src/homelab/deployment/k8s-manifests/nextcloud.yaml

# 7. Deploy Pi-hole for DNS filtering
log "Deploying Pi-hole..."
cat > /home/ubuntu/src/homelab/deployment/k8s-manifests/pihole.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pihole
  namespace: homelab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pihole
  template:
    metadata:
      labels:
        app: pihole
    spec:
      containers:
      - name: pihole
        image: pihole/pihole:latest
        ports:
        - containerPort: 80
          name: web
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
        - containerPort: 53
          name: dns-udp
          protocol: UDP
        env:
        - name: TZ
          value: "UTC"
        - name: WEBPASSWORD
          value: "admin123"
        volumeMounts:
        - name: config
          mountPath: /etc/pihole
        - name: dnsmasq
          mountPath: /etc/dnsmasq.d
      volumes:
      - name: config
        persistentVolumeClaim:
          claimName: pihole-config-pvc
      - name: dnsmasq
        persistentVolumeClaim:
          claimName: pihole-dnsmasq-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: pihole-web
  namespace: homelab
spec:
  type: LoadBalancer
  selector:
    app: pihole
  ports:
  - port: 80
    targetPort: 80
    name: web
---
apiVersion: v1
kind: Service
metadata:
  name: pihole-dns
  namespace: homelab
spec:
  type: LoadBalancer
  selector:
    app: pihole
  ports:
  - port: 53
    targetPort: 53
    protocol: TCP
    name: dns-tcp
  - port: 53
    targetPort: 53
    protocol: UDP
    name: dns-udp
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pihole-config-pvc
  namespace: homelab
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-fast
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pihole-dnsmasq-pvc
  namespace: homelab
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-fast
  resources:
    requests:
      storage: 5Gi
EOF

kubectl apply -f /home/ubuntu/src/homelab/deployment/k8s-manifests/pihole.yaml

# 8. Deploy Portainer for Container Management
log "Deploying Portainer..."
cat > /home/ubuntu/src/homelab/deployment/k8s-manifests/portainer.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portainer
  namespace: homelab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: portainer
  template:
    metadata:
      labels:
        app: portainer
    spec:
      serviceAccountName: portainer
      containers:
      - name: portainer
        image: portainer/portainer-ce:latest
        ports:
        - containerPort: 9000
        - containerPort: 9443
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: portainer-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: portainer
  namespace: homelab
spec:
  type: LoadBalancer
  selector:
    app: portainer
  ports:
  - port: 9000
    targetPort: 9000
    name: http
  - port: 9443
    targetPort: 9443
    name: https
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: portainer-pvc
  namespace: homelab
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-fast
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: portainer
  namespace: homelab
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: portainer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: portainer
  namespace: homelab
EOF

kubectl apply -f /home/ubuntu/src/homelab/deployment/k8s-manifests/portainer.yaml

# Wait for deployments to be ready
log "Waiting for services to be ready..."
kubectl wait --for=condition=available --timeout=600s deployment --all -n monitoring || true
kubectl wait --for=condition=available --timeout=600s deployment --all -n homelab || true

# Get service URLs
log "✅ Homelab services deployment completed!"
echo ""
echo "📋 Service Access URLs:"
echo "=================================="
kubectl get svc -A | grep LoadBalancer | awk '{print $2 " (" $1 "): http://" $5 ":" $6}' | sed 's/\/TCP//'

echo ""
echo "Default Credentials:"
echo "===================="
echo "Grafana: admin/admin"
echo "Pi-hole: admin/admin123"
echo "Nextcloud: admin/admin123"
echo "Home Assistant: Configure on first login"
echo "Plex: Configure on first login"

log "All services deployed successfully!"