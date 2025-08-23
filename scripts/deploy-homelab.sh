#!/bin/bash
# Ultimate Homelab Deployment Script
# Deploys distributed services across Kubernetes cluster with powerful monitoring

set -euo pipefail

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
KUBE_CONFIG="${HOME}/.kube/config"

# Service distribution map
declare -A NODE_LABELS=(
    ["services"]="homelab.role=services"
    ["infrastructure"]="homelab.role=infrastructure" 
    ["network"]="homelab.role=network"
    ["storage"]="homelab.role=storage"
    ["media"]="homelab.role=media"
    ["management"]="homelab.role=management"
    ["gateway"]="homelab.role=gateway"
    ["monitoring"]="homelab.role=monitoring"
    ["gpu"]="homelab.gpu=true"
)

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] 🚀 $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  INFO: $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ SUCCESS: $1${NC}"
}

banner() {
    echo -e "${PURPLE}${BOLD}"
    echo "=================================================="
    echo "    🏠 DARK KNIGHT HOMELAB DEPLOYMENT 🏠"
    echo "=================================================="
    echo -e "${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        error "helm not found. Please install helm."
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Label nodes for service distribution
label_nodes() {
    log "Labeling nodes for optimal service distribution..."
    
    local nodes=($(kubectl get nodes --no-headers -o custom-columns=":metadata.name"))
    local node_count=${#nodes[@]}
    
    if [ $node_count -eq 0 ]; then
        error "No nodes found in cluster"
        exit 1
    fi
    
    log "Found $node_count nodes in cluster"
    
    # Label master nodes
    for node in "${nodes[@]}"; do
        if kubectl get node "$node" -o jsonpath='{.metadata.labels}' | grep -q "node-role.kubernetes.io/control-plane"; then
            kubectl label node "$node" homelab.role=management --overwrite
            kubectl label node "$node" homelab.role=monitoring --overwrite
            info "Labeled master node: $node"
        fi
    done
    
    # Label worker nodes with specific roles
    local worker_nodes=($(kubectl get nodes --no-headers -l '!node-role.kubernetes.io/control-plane' -o custom-columns=":metadata.name"))
    local worker_count=${#worker_nodes[@]}
    
    if [ $worker_count -gt 0 ]; then
        # First worker: GPU and media services
        kubectl label node "${worker_nodes[0]}" homelab.gpu=true --overwrite
        kubectl label node "${worker_nodes[0]}" homelab.role=media --overwrite
        kubectl label node "${worker_nodes[0]}" homelab.role=services --overwrite
        info "Labeled GPU/Media node: ${worker_nodes[0]}"
        
        # Second worker: Storage and infrastructure
        if [ $worker_count -gt 1 ]; then
            kubectl label node "${worker_nodes[1]}" homelab.role=storage --overwrite
            kubectl label node "${worker_nodes[1]}" homelab.role=infrastructure --overwrite
            info "Labeled Storage node: ${worker_nodes[1]}"
        fi
        
        # Third worker: Network and gateway
        if [ $worker_count -gt 2 ]; then
            kubectl label node "${worker_nodes[2]}" homelab.role=network --overwrite
            kubectl label node "${worker_nodes[2]}" homelab.role=gateway --overwrite
            info "Labeled Network node: ${worker_nodes[2]}"
        fi
    fi
    
    success "Node labeling completed"
}

# Install Helm repositories
install_helm_repos() {
    log "Adding Helm repositories..."
    
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo add jetstack https://charts.jetstack.io
    helm repo add longhorn https://charts.longhorn.io
    helm repo add metallb https://metallb.github.io/metallb
    
    helm repo update
    
    success "Helm repositories updated"
}

# Deploy storage layer
deploy_storage() {
    log "Deploying Longhorn distributed storage..."
    
    kubectl create namespace longhorn-system --dry-run=client -o yaml | kubectl apply -f -
    
    helm upgrade --install longhorn longhorn/longhorn \
        --namespace longhorn-system \
        --set defaultSettings.defaultDataPath="/var/lib/longhorn/" \
        --set defaultSettings.replicaCount=3 \
        --set defaultSettings.defaultDataLocality="best-effort" \
        --set persistence.defaultClass=true \
        --set persistence.defaultClassReplicaCount=3 \
        --set ingress.enabled=true \
        --set ingress.host="longhorn.homelab.local" \
        --set service.ui.nodePort=null \
        --wait
    
    success "Longhorn storage deployed"
}

# Deploy network layer
deploy_networking() {
    log "Deploying networking components..."
    
    # MetalLB Load Balancer
    kubectl create namespace metallb-system --dry-run=client -o yaml | kubectl apply -f -
    
    helm upgrade --install metallb metallb/metallb \
        --namespace metallb-system \
        --set controller.nodeSelector."homelab\.role"=network \
        --set speaker.nodeSelector."homelab\.role"=network \
        --wait
    
    # Configure MetalLB IP pool
    cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: homelab-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.2.0.100-10.2.0.150
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: homelab-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - homelab-pool
EOF

    # NGINX Ingress Controller
    kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
    
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --set controller.nodeSelector."homelab\.role"=gateway \
        --set controller.service.type=LoadBalancer \
        --set controller.service.loadBalancerIP=10.2.0.100 \
        --set controller.metrics.enabled=true \
        --set controller.podAnnotations."prometheus\.io/scrape"="true" \
        --set controller.podAnnotations."prometheus\.io/port"="10254" \
        --wait
    
    success "Networking components deployed"
}

# Deploy cert-manager
deploy_cert_manager() {
    log "Deploying cert-manager for TLS certificates..."
    
    kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
    
    helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --set installCRDs=true \
        --set nodeSelector."homelab\.role"=management \
        --wait
    
    # Create cluster issuer
    cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@homelab.local
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
    
    success "cert-manager deployed"
}

# Deploy monitoring stack
deploy_monitoring() {
    log "Deploying comprehensive monitoring stack..."
    
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Install kube-prometheus-stack
    helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --values "$PROJECT_ROOT/services/monitoring-stack/values.yaml" \
        --wait
    
    # Deploy custom monitoring components
    kubectl apply -f "$PROJECT_ROOT/kubernetes/monitoring-stack/deploy.yaml"
    
    success "Monitoring stack deployed"
}

# Deploy homelab services
deploy_homelab_services() {
    log "Deploying homelab services..."
    
    # Create namespaces for different service categories
    local namespaces=("media" "home-automation" "infrastructure" "storage")
    for ns in "${namespaces[@]}"; do
        kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
        kubectl label namespace "$ns" name="$ns"
    done
    
    # Deploy Plex Media Server
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: plex
  namespace: media
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
      nodeSelector:
        homelab.role: media
        homelab.gpu: "true"
      containers:
      - name: plex
        image: linuxserver/plex:latest
        env:
        - name: PUID
          value: "1000"
        - name: PGID
          value: "1000"
        - name: VERSION
          value: "docker"
        ports:
        - containerPort: 32400
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
            cpu: "8"
            memory: "16Gi"
            nvidia.com/gpu: 1
      volumes:
      - name: config
        persistentVolumeClaim:
          claimName: plex-config
      - name: media
        persistentVolumeClaim:
          claimName: plex-media
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: plex-config
  namespace: media
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 50Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: plex-media
  namespace: media
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Ti
---
apiVersion: v1
kind: Service
metadata:
  name: plex
  namespace: media
spec:
  selector:
    app: plex
  type: LoadBalancer
  loadBalancerIP: 10.2.0.110
  ports:
  - port: 32400
    targetPort: 32400
EOF

    # Deploy Home Assistant
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: home-assistant
  namespace: home-automation
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
      nodeSelector:
        homelab.role: services
      hostNetwork: true
      containers:
      - name: home-assistant
        image: ghcr.io/home-assistant/home-assistant:stable
        ports:
        - containerPort: 8123
        volumeMounts:
        - name: config
          mountPath: /config
        resources:
          requests:
            cpu: "1"
            memory: "2Gi"
          limits:
            cpu: "2"
            memory: "4Gi"
      volumes:
      - name: config
        persistentVolumeClaim:
          claimName: home-assistant-config
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: home-assistant-config
  namespace: home-automation
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: Service
metadata:
  name: home-assistant
  namespace: home-automation
spec:
  selector:
    app: home-assistant
  type: LoadBalancer
  loadBalancerIP: 10.2.0.111
  ports:
  - port: 8123
    targetPort: 8123
EOF

    success "Homelab services deployed"
}

# Create ingress routes
create_ingress_routes() {
    log "Creating ingress routes for web access..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: homelab-services
  namespace: media
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - plex.homelab.local
    secretName: plex-tls
  rules:
  - host: plex.homelab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: plex
            port:
              number: 32400
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: home-automation-services
  namespace: home-automation
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - homeassistant.homelab.local
    secretName: homeassistant-tls
  rules:
  - host: homeassistant.homelab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: home-assistant
            port:
              number: 8123
EOF
    
    success "Ingress routes created"
}

# Display service URLs
display_service_urls() {
    log "Getting service access information..."
    
    local ingress_ip=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ -z "$ingress_ip" ]; then
        warn "Ingress IP not yet assigned. Services may take a few minutes to be accessible."
        return
    fi
    
    echo -e "${CYAN}${BOLD}"
    echo "=================================================="
    echo "🌐 SERVICE ACCESS INFORMATION"
    echo "=================================================="
    echo -e "${NC}"
    
    echo -e "${GREEN}📊 Monitoring Services:${NC}"
    echo "  • Grafana:     https://grafana.homelab.local"
    echo "  • Prometheus:  https://prometheus.homelab.local"
    echo "  • Longhorn:    https://longhorn.homelab.local"
    echo ""
    
    echo -e "${BLUE}🏠 Homelab Services:${NC}"
    echo "  • Plex:        https://plex.homelab.local"
    echo "  • Home Assistant: https://homeassistant.homelab.local"
    echo ""
    
    echo -e "${YELLOW}🔧 Direct Access (LoadBalancer IPs):${NC}"
    echo "  • Plex:        http://10.2.0.110:32400"
    echo "  • Home Assistant: http://10.2.0.111:8123"
    echo ""
    
    echo -e "${PURPLE}📝 Add to /etc/hosts (or local DNS):${NC}"
    echo "  $ingress_ip grafana.homelab.local"
    echo "  $ingress_ip prometheus.homelab.local"
    echo "  $ingress_ip longhorn.homelab.local"
    echo "  $ingress_ip plex.homelab.local"
    echo "  $ingress_ip homeassistant.homelab.local"
    echo ""
}

# Main deployment function
main() {
    banner
    
    log "Starting Ultimate Homelab deployment..."
    
    check_prerequisites
    label_nodes
    install_helm_repos
    
    # Deploy infrastructure layers
    deploy_storage
    deploy_networking
    deploy_cert_manager
    
    # Deploy application layers  
    deploy_monitoring
    deploy_homelab_services
    create_ingress_routes
    
    # Wait for services to be ready
    log "Waiting for services to be ready..."
    kubectl wait --for=condition=ready pod -l app=plex -n media --timeout=300s || true
    kubectl wait --for=condition=ready pod -l app=home-assistant -n home-automation --timeout=300s || true
    
    success "🎉 Ultimate Homelab deployment completed!"
    
    display_service_urls
    
    echo -e "${GREEN}${BOLD}"
    echo "=================================================="
    echo "🚀 DEPLOYMENT COMPLETE!"
    echo "Your homelab is now running with:"
    echo "• High-performance GPU monitoring (RTX 4080)"
    echo "• Distributed storage with Longhorn"
    echo "• Powerful Grafana dashboards"
    echo "• Media services with hardware acceleration"
    echo "• Smart home automation"
    echo "• Production-grade monitoring stack"
    echo "=================================================="
    echo -e "${NC}"
}

# Error handling
trap 'error "Deployment failed at line $LINENO"' ERR

# Run main function
main "$@"