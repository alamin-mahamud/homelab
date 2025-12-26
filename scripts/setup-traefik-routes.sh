#!/bin/bash
# Setup Traefik routes for homelab services

set -e

echo "=== Traefik Routes Setup ==="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get Traefik LoadBalancer IP
echo -e "\n${YELLOW}Getting Traefik LoadBalancer IP...${NC}"
TRAEFIK_IP=$(kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$TRAEFIK_IP" ]; then
    echo -e "${RED}Error: Could not get Traefik IP. Is MetalLB configured?${NC}"
    echo "Check with: kubectl get svc -n traefik traefik"
    exit 1
fi

echo -e "${GREEN}Traefik LoadBalancer IP: $TRAEFIK_IP${NC}"

# Deploy IngressRoutes
echo -e "\n${YELLOW}Deploying IngressRoutes...${NC}"

# Grafana
echo "Deploying Grafana IngressRoute..."
kubectl apply -f ../monitoring/grafana-ingress.yaml

# Prometheus & AlertManager
echo "Deploying Prometheus IngressRoute..."
kubectl apply -f ../monitoring/prometheus-ingress.yaml

# Traefik Dashboard
echo "Deploying Traefik Dashboard IngressRoute..."
kubectl apply -f ../monitoring/traefik-dashboard-ingress.yaml

echo -e "\n${GREEN}IngressRoutes deployed successfully!${NC}"

# Show DNS entries to add
echo -e "\n${YELLOW}=== Add these DNS entries to your DNS server or /etc/hosts ===${NC}"
cat <<EOF

# Traefik-routed services
$TRAEFIK_IP    grafana.homelab.local
$TRAEFIK_IP    prometheus.homelab.local
$TRAEFIK_IP    alertmanager.homelab.local
$TRAEFIK_IP    traefik.homelab.local

EOF
ud
echo -e "${YELLOW}=== Pi-hole Configuration ===${NC}"
echo "Add these to Pi-hole > Local DNS > DNS Records:"
echo "  Domain: grafana.homelab.local -> IP: $TRAEFIK_IP"
echo "  Domain: prometheus.homelab.local -> IP: $TRAEFIK_IP"
echo "  Domain: alertmanager.homelab.local -> IP: $TRAEFIK_IP"
echo "  Domain: traefik.homelab.local -> IP: $TRAEFIK_IP"

# Check IngressRoutes
echo -e "\n${YELLOW}=== IngressRoute Status ===${NC}"
kubectl get ingressroute -A

# Show services
echo -e "\n${YELLOW}=== Available Services ===${NC}"
echo -e "${GREEN}Grafana:${NC}       http://grafana.homelab.local"
echo -e "${GREEN}Prometheus:${NC}    http://prometheus.homelab.local"
echo -e "${GREEN}AlertManager:${NC}  http://alertmanager.homelab.local"
echo -e "${GREEN}Traefik:${NC}       http://traefik.homelab.local"

# Test connectivity
echo -e "\n${YELLOW}=== Testing Traefik Connectivity ===${NC}"
if curl -s -o /dev/null -w "%{http_code}" http://$TRAEFIK_IP | grep -q "404"; then
    echo -e "${GREEN}✓ Traefik is responding${NC}"
else
    echo -e "${RED}✗ Traefik is not responding. Check the service.${NC}"
fi

echo -e "\n${YELLOW}=== Next Steps ===${NC}"
echo "1. Add DNS entries above to your DNS server"
echo "2. Test access: curl -H 'Host: grafana.homelab.local' http://$TRAEFIK_IP"
echo "3. Access services via browser at the URLs above"
echo "4. View Traefik dashboard to verify routes"

echo -e "\n${GREEN}Setup complete!${NC}"
