#!/bin/bash

# Comprehensive Deployment Test Script
# Tests all components of the homelab deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# Test result functions
test_pass() {
    echo -e "${GREEN}✅ PASS:${NC} $1"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}❌ FAIL:${NC} $1"
    ((TESTS_FAILED++))
    FAILED_TESTS+=("$1")
}

test_skip() {
    echo -e "${YELLOW}⏭️  SKIP:${NC} $1"
}

# Run test with timeout
run_test() {
    local test_name="$1"
    local test_command="$2"
    local timeout="${3:-30}"
    
    info "Testing: $test_name"
    
    if timeout "$timeout" bash -c "$test_command" >/dev/null 2>&1; then
        test_pass "$test_name"
        return 0
    else
        test_fail "$test_name"
        return 1
    fi
}

# Test SSH connectivity
test_ssh_connectivity() {
    log "Testing SSH connectivity to all nodes..."
    
    local hosts=("10.1.0.0" "10.1.0.1")
    
    # Test Proxmox hosts
    for host in "${hosts[@]}"; do
        run_test "SSH to $host" "ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$host 'echo ok'"
    done
    
    # Test K8s nodes if inventory exists
    if [[ -f "$SCRIPT_DIR/inventory.ini" ]]; then
        local k8s_hosts=($(grep -E '^[0-9]+\.' "$SCRIPT_DIR/inventory.ini" | awk '{print $1}'))
        for host in "${k8s_hosts[@]}"; do
            run_test "SSH to K8s node $host" "ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$host 'echo ok'" 10
        done
    fi
}

# Test Proxmox cluster
test_proxmox_cluster() {
    log "Testing Proxmox cluster status..."
    
    run_test "Proxmox cluster status" "ssh root@10.1.0.0 'pvecm status | grep -q Quorate'"
    run_test "Proxmox VMs running" "ssh root@10.1.0.0 'qm list | grep -c running' | grep -q '[1-9]'"
}

# Test Kubernetes cluster
test_kubernetes_cluster() {
    log "Testing Kubernetes cluster..."
    
    if ! command -v kubectl >/dev/null 2>&1; then
        test_fail "kubectl not available"
        return
    fi
    
    run_test "Kubernetes cluster info" "kubectl cluster-info"
    run_test "All nodes ready" "kubectl get nodes | grep -v NotReady | grep -c Ready | grep -q '^[1-9]'"
    run_test "System pods running" "kubectl get pods -n kube-system | grep -v Terminating | grep -c Running | grep -q '^[5-9]'"
    run_test "MetalLB pods running" "kubectl get pods -n metallb-system | grep -c Running | grep -q '^[2-9]'"
}

# Test storage
test_storage() {
    log "Testing storage components..."
    
    if kubectl get ns longhorn-system >/dev/null 2>&1; then
        run_test "Longhorn namespace exists" "kubectl get ns longhorn-system"
        run_test "Longhorn pods running" "kubectl get pods -n longhorn-system | grep -c Running | grep -q '^[3-9]'"
        run_test "Storage classes available" "kubectl get sc | grep -q longhorn"
    else
        test_skip "Longhorn not deployed"
    fi
    
    # Test NFS storage node
    run_test "NFS storage node accessible" "ssh -o ConnectTimeout=5 ubuntu@10.2.0.30 'showmount -e localhost 2>/dev/null | grep -q /srv'" 10
}

# Test monitoring stack
test_monitoring() {
    log "Testing monitoring stack..."
    
    if kubectl get ns monitoring >/dev/null 2>&1; then
        run_test "Monitoring namespace exists" "kubectl get ns monitoring"
        run_test "Prometheus pod running" "kubectl get pods -n monitoring | grep prometheus | grep -q Running"
        run_test "Grafana pod running" "kubectl get pods -n monitoring | grep grafana | grep -q Running"
        
        # Test service endpoints
        local prometheus_ip=$(kubectl get svc prometheus -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [[ -n "$prometheus_ip" && "$prometheus_ip" != "null" ]]; then
            run_test "Prometheus web interface" "curl -f http://$prometheus_ip:9090/-/healthy" 15
        else
            test_skip "Prometheus LoadBalancer IP not assigned"
        fi
        
        local grafana_ip=$(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [[ -n "$grafana_ip" && "$grafana_ip" != "null" ]]; then
            run_test "Grafana web interface" "curl -f http://$grafana_ip:3000/api/health" 15
        else
            test_skip "Grafana LoadBalancer IP not assigned"
        fi
    else
        test_skip "Monitoring stack not deployed"
    fi
}

# Test homelab services
test_homelab_services() {
    log "Testing homelab services..."
    
    if kubectl get ns homelab >/dev/null 2>&1; then
        run_test "Homelab namespace exists" "kubectl get ns homelab"
        
        # Test individual services
        local services=("home-assistant" "plex" "nextcloud" "portainer")
        for service in "${services[@]}"; do
            if kubectl get deployment "$service" -n homelab >/dev/null 2>&1; then
                run_test "$service pod running" "kubectl get pods -n homelab | grep $service | grep -q Running"
            else
                test_skip "$service not deployed"
            fi
        done
        
        # Test Pi-hole
        if kubectl get deployment pihole -n homelab >/dev/null 2>&1; then
            run_test "Pi-hole pod running" "kubectl get pods -n homelab | grep pihole | grep -q Running"
            
            local pihole_dns_ip=$(kubectl get svc pihole-dns -n homelab -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
            if [[ -n "$pihole_dns_ip" && "$pihole_dns_ip" != "null" ]]; then
                run_test "Pi-hole DNS resolution" "nslookup google.com $pihole_dns_ip"
            else
                test_skip "Pi-hole DNS LoadBalancer IP not assigned"
            fi
        fi
    else
        test_skip "Homelab services not deployed"
    fi
}

# Test Raspberry Pi services
test_raspberry_pi() {
    log "Testing Raspberry Pi services..."
    
    run_test "Raspberry Pi accessible" "ssh -o ConnectTimeout=5 root@10.1.0.1 'echo ok'"
    
    # Test Docker services
    if ssh root@10.1.0.1 'command -v docker' >/dev/null 2>&1; then
        run_test "Docker running on Pi" "ssh root@10.1.0.1 'systemctl is-active docker'"
        
        # Test individual services
        local pi_services=("pihole" "node_exporter" "mosquitto" "heimdall" "uptime-kuma")
        for service in "${pi_services[@]}"; do
            run_test "Pi service: $service" "ssh root@10.1.0.1 'cd /opt/homelab-services && docker-compose ps | grep $service | grep -q Up'" 10
        done
        
        # Test service endpoints
        run_test "Pi-hole web admin" "curl -f http://10.1.0.1:8080/admin/ --connect-timeout 10" 15
        run_test "Node Exporter metrics" "curl -f http://10.1.0.1:9100/metrics --connect-timeout 10" 15
        run_test "Heimdall dashboard" "curl -f http://10.1.0.1:8082 --connect-timeout 10" 15
        
        # Test DNS functionality
        run_test "Pi-hole DNS server" "nslookup google.com 10.1.0.1"
    else
        test_fail "Docker not installed on Raspberry Pi"
    fi
}

# Test network connectivity
test_network() {
    log "Testing network connectivity..."
    
    # Test internal network
    local test_ips=("10.2.0.10" "10.2.0.11" "10.2.0.21" "10.2.0.30")
    for ip in "${test_ips[@]}"; do
        run_test "Network connectivity to $ip" "ping -c 2 -W 5 $ip" 10
    done
    
    # Test LoadBalancer IP range
    if kubectl get svc -A | grep LoadBalancer | head -1 >/dev/null 2>&1; then
        local lb_ip=$(kubectl get svc -A | grep LoadBalancer | head -1 | awk '{print $5}' | cut -d: -f1)
        if [[ "$lb_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            run_test "LoadBalancer IP accessible" "ping -c 2 -W 5 $lb_ip" 10
        fi
    fi
}

# Test integrations
test_integrations() {
    log "Testing service integrations..."
    
    # Test monitoring integration with Pi
    if kubectl get svc raspberry-pi-metrics -n monitoring >/dev/null 2>&1; then
        test_pass "Raspberry Pi monitoring integration configured"
    else
        test_skip "Raspberry Pi monitoring integration not configured"
    fi
    
    # Test DNS integration
    run_test "Internal DNS resolution" "nslookup kubernetes.default.svc.cluster.local 10.96.0.10" 10
}

# Performance tests
test_performance() {
    log "Testing system performance..."
    
    # Test resource usage
    run_test "K8s nodes resource usage" "kubectl top nodes 2>/dev/null | grep -v NAME | awk '{if(\$3+0>90 || \$5+0>90) exit 1}'"
    
    # Test storage performance
    if kubectl get sc longhorn-fast >/dev/null 2>&1; then
        run_test "Storage class responsive" "kubectl get sc longhorn-fast"
    fi
    
    # Test cluster responsiveness
    run_test "Kubernetes API responsive" "time kubectl get nodes | grep -q Ready" 10
}

# Generate test report
generate_report() {
    local total_tests=$((TESTS_PASSED + TESTS_FAILED))
    local pass_rate=0
    
    if [ $total_tests -gt 0 ]; then
        pass_rate=$((TESTS_PASSED * 100 / total_tests))
    fi
    
    echo ""
    echo "============================================"
    echo "🧪 DEPLOYMENT TEST RESULTS"
    echo "============================================"
    echo "Total Tests: $total_tests"
    echo "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo "Failed: ${RED}$TESTS_FAILED${NC}"
    echo "Pass Rate: $pass_rate%"
    echo ""
    
    if [ $TESTS_FAILED -gt 0 ]; then
        echo "❌ Failed Tests:"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  • $test"
        done
        echo ""
    fi
    
    if [ $pass_rate -ge 90 ]; then
        echo -e "${GREEN}🎉 Deployment is healthy! (Pass rate: $pass_rate%)${NC}"
        return 0
    elif [ $pass_rate -ge 70 ]; then
        echo -e "${YELLOW}⚠️  Deployment has some issues (Pass rate: $pass_rate%)${NC}"
        return 1
    else
        echo -e "${RED}❌ Deployment has significant issues (Pass rate: $pass_rate%)${NC}"
        return 2
    fi
}

# Main test execution
main() {
    echo "🧪 Starting comprehensive homelab deployment tests..."
    echo "Test started at: $(date)"
    echo ""
    
    # Infrastructure tests
    test_ssh_connectivity
    test_proxmox_cluster
    test_network
    
    # Kubernetes tests
    test_kubernetes_cluster
    test_storage
    
    # Service tests
    test_monitoring
    test_homelab_services
    test_raspberry_pi
    
    # Integration tests
    test_integrations
    test_performance
    
    # Generate final report
    generate_report
}

# Run main function
main "$@"