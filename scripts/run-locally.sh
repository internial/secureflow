#!/bin/bash
set -Eeuo pipefail

# SecureFlow Full Local Test Orchestration Script
#
# Workflow overview:
#   Phase 1 – Docker Compose  : Validate the application (Spring Boot + PostgreSQL +
#                                Prometheus + Grafana) under 100 VU spike load.
#   Phase 2 – Kind Kubernetes : Validate Kubernetes (HPA, service routing, networking)
#                                under the same 100 VU spike load.
#   Phase 3 – Simulations     : Validate observability, alerting, and self-healing via
#                                crash, memory, and failed-deploy scenarios.
#   Phase 4 – Teardown        : Clean up all local resources.
#
# Both load test phases reuse scripts/k6-spike.js (100 VUs, ramp-up → hold → ramp-down).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/local-env.sh"
cd "${SECUREFLOW_REPO_ROOT}"

# Color formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

success() {
    echo -e "${GREEN}✓${NC} $1"
}

failure() {
    echo -e "${RED}✗${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

phase() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

PORT_FORWARD_PIDS=()

cleanup_port_forwards() {
    if ((${#PORT_FORWARD_PIDS[@]} == 0)); then
        return
    fi

    for pid in "${PORT_FORWARD_PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done

    for pid in "${PORT_FORWARD_PIDS[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    PORT_FORWARD_PIDS=()
}

trap cleanup_port_forwards EXIT

echo -e "${BOLD}====================================================${NC}"
echo -e "${BOLD}    SecureFlow - Full Local Test Orchestration     ${NC}"
echo -e "${BOLD}====================================================${NC}"

for cmd in docker curl k6 kind kubectl helm; do
    require_command "$cmd"
done

# Check and setup git-secrets if not installed
if ! command -v git-secrets > /dev/null 2>&1; then
    phase "Security Setup - Installing git-secrets"
    info "git-secrets not found. Installing for secret scanning protection..."
    "${SCRIPT_DIR}/setup-git-secrets.sh"
    success "git-secrets installed and configured"
else
    info "git-secrets already installed ✓"
fi

wait_for_docker

# The Kind ingress mapping in kind-config.yaml also uses host port 8080.
# Recreate the cluster during this run so Phase 1 can bind Compose to 8080 first.
if kind get clusters | grep -qx secureflow; then
    warning "Deleting existing Kind cluster 'secureflow' to free local ports..."
    kind delete cluster --name secureflow
fi

# ─────────────────────────────────────────────────────────────────────────────
# Phase 1 – Docker Compose
# Objective: Validate the application itself (Spring Boot + PostgreSQL +
#            Prometheus + Grafana) under spike load. No Kubernetes involved.
# ─────────────────────────────────────────────────────────────────────────────
phase "[Phase 1/4] Docker Compose – Application Validation"
docker compose down --remove-orphans
docker compose up -d --build
info "Waiting for services to be healthy..."
sleep 15

# Health checks
echo ""
info "Running application health checks..."

if curl -sf http://localhost:8080/actuator/health > /dev/null; then
    success "Actuator health check passed  (http://localhost:8080/actuator/health)"
else
    failure "Actuator health check failed"
    exit 1
fi

if curl -sf http://localhost:8080/api/users > /dev/null; then
    success "API endpoint check passed     (http://localhost:8080/api/users)"
else
    failure "API endpoint check failed"
    exit 1
fi

# 100 VU spike test against Docker Compose
echo ""
info "Running 100 VU spike load test against Docker Compose..."
info "Purpose: verify application handles spike traffic (not Kubernetes behaviour)."
TARGET_URL=http://localhost:8080/api/users k6 run scripts/k6-spike.js

echo ""
echo -e "${BOLD}====================================================${NC}"
echo -e "${YELLOW}  PAUSED: Inspect Docker Compose Metrics${NC}"
echo -e "${BOLD}====================================================${NC}"
echo ""
info "Verify application-level behaviour after the spike test."
echo ""
echo -e "${CYAN}📈 GRAFANA (http://localhost:3000 - admin/admin):${NC}"
echo "   Dashboard: 'SecureFlow'"
echo "   Verify:"
echo "     • Request Rate"
echo "     • CPU Usage"
echo "     • Memory Usage"
echo "     • p95 Latency"
echo "     • Error Rate"
echo ""
echo -e "${CYAN}🔍 PROMETHEUS (http://localhost:9090):${NC}"
echo "   Query: rate(http_server_requests_seconds_count[1m])"
echo "   Check 'Status → Targets' to confirm secureflow-app is scraped"
echo ""
echo -e "${YELLOW}Note: Kubernetes metrics (pod replicas, HPA) are NOT expected here.${NC}"
echo -e "${YELLOW}      Those are validated in Phase 2.${NC}"
echo ""
echo -e "${YELLOW}Press Enter when done inspecting Docker Compose metrics...${NC}"
read

# ─────────────────────────────────────────────────────────────────────────────
# Phase 2 – Kind Kubernetes
# Objective: Validate Kubernetes-level behaviour (HPA, pod scaling, service
#            routing, networking) using the same 100 VU spike load.
# ─────────────────────────────────────────────────────────────────────────────
phase "[Phase 2/4] Kind Kubernetes – Kubernetes Validation"
docker compose down
"${SCRIPT_DIR}/kind-cluster-setup.sh"

# Health checks via port-forward
echo ""
info "Setting up port-forward for Kind health checks..."
kubectl port-forward -n secureflow svc/secureflow 8888:80 &
PF_PID=$!
PORT_FORWARD_PIDS+=("$PF_PID")
sleep 5

info "Running application health checks on Kind cluster..."

if curl -sf http://localhost:8888/actuator/health > /dev/null; then
    success "Actuator health check passed  (http://localhost:8888/actuator/health)"
else
    failure "Actuator health check failed on Kind"
    exit 1
fi

if curl -sf http://localhost:8888/api/users > /dev/null; then
    success "API endpoint check passed     (http://localhost:8888/api/users)"
else
    failure "API endpoint check failed on Kind"
    exit 1
fi

# Set up monitoring port-forwards (offset ports to avoid conflicts with Compose)
echo ""
info "Setting up monitoring port-forwards (Prometheus 9091, Grafana 3001)..."
kubectl port-forward -n monitoring svc/prometheus 9091:9090 &
PROM_PID=$!
PORT_FORWARD_PIDS+=("$PROM_PID")
kubectl port-forward -n monitoring svc/grafana 3001:3000 &
GRAF_PID=$!
PORT_FORWARD_PIDS+=("$GRAF_PID")
sleep 5

success "Monitoring stack accessible:"
echo "   Prometheus: http://localhost:9091"
echo "   Grafana:    http://localhost:3001 (admin/admin)"

# 100 VU spike test against Kind – same test, different validation layer
echo ""
info "Running 100 VU spike load test against Kind cluster..."
info "Purpose: verify Kubernetes routes traffic correctly and HPA scales under load."
TARGET_URL=http://localhost:8888/api/users k6 run scripts/k6-spike.js

echo ""
echo -e "${BOLD}====================================================${NC}"
echo -e "${YELLOW}  PAUSED: Inspect Kind Cluster Metrics${NC}"
echo -e "${BOLD}====================================================${NC}"
echo ""
info "Verify Kubernetes-level behaviour after the spike test."
echo ""
echo -e "${CYAN}📈 GRAFANA (http://localhost:3001 - admin/admin):${NC}"
echo "   Dashboard: 'SecureFlow'"
echo "   Verify:"
echo "     • Request Rate"
echo "     • CPU Usage"
echo "     • Memory Usage"
echo "     • p95 Latency"
echo "     • Error Rate"
echo "     • Pod Replica Count (HPA scaling)"
echo ""
echo -e "${CYAN}🔍 PROMETHEUS (http://localhost:9091):${NC}"
echo "   Request Rate:    rate(http_server_requests_seconds_count[1m])"
echo "   p95 Latency:     histogram_quantile(0.95, rate(http_server_requests_seconds_bucket[1m]))"
echo "   Error Rate:      rate(http_server_requests_seconds_count{status=~\"5..\"}[1m]) / rate(http_server_requests_seconds_count[1m])"
echo "   Pod Replicas:    kube_deployment_status_replicas_available"
echo "   JVM Memory:      jvm_memory_used_bytes"
echo "   JVM CPU:         rate(jvm_cpu_usage[1m]) * 100"
echo ""
echo -e "${CYAN}🔄 KUBERNETES (HPA & Routing):${NC}"
echo "   kubectl get hpa -n secureflow"
echo "   kubectl get pods -n secureflow"
echo ""
echo -e "${YELLOW}Press Enter when done inspecting Kind cluster metrics...${NC}"
read

# ─────────────────────────────────────────────────────────────────────────────
# Phase 3 – Incident Simulations
# Objective: Validate observability, alerting, self-healing, and operational
#            recovery after crash, memory stress, and failed-deploy scenarios.
# ─────────────────────────────────────────────────────────────────────────────
phase "[Phase 3/4] Incident Simulations – Observability & Recovery Validation"

echo ""
info "Running pod crash simulation..."
./scripts/simulate-crash.sh

echo ""
info "Running memory stress simulation..."
./scripts/simulate-memory.sh
kubectl delete pod secureflow-memory-stressor -n secureflow --ignore-not-found=true

echo ""
info "Running failed deployment simulation..."
./scripts/simulate-failed-deploy.sh

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}${BOLD}  📊 AUTOMATED METRICS COLLECTION${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
info "Waiting 10 seconds for metrics to propagate after simulations..."
sleep 10
"${SCRIPT_DIR}/check-monitoring.sh" http://localhost:9091
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo -e "${BOLD}====================================================${NC}"
echo -e "${MAGENTA}  🔍  PAUSED: Inspect Post-Simulation Metrics  🔍${NC}"
echo -e "${BOLD}====================================================${NC}"
echo ""
info "Verify observability, alerting, and system recovery."
echo ""
echo -e "${CYAN}📈 GRAFANA (http://localhost:3001 - admin/admin):${NC}"
echo "   Dashboard: 'SecureFlow'"
echo "   Verify:"
echo "     • Alerts triggered correctly"
echo "     • Pod recreation / self-healing after crash"
echo "     • Memory spike detected"
echo "     • Failed deployment detected"
echo "     • System returns to healthy state after recovery"
echo ""
echo -e "${CYAN}🔍 PROMETHEUS (http://localhost:9091):${NC}"
echo "   Pod Replicas:    kube_deployment_status_replicas_available"
echo "   JVM Memory:      jvm_memory_used_bytes"
echo "   JVM CPU:         rate(jvm_cpu_usage[1m]) * 100"
echo "   Error Rate:      rate(http_server_requests_seconds_count{status=~\"5..\"}[1m]) / rate(http_server_requests_seconds_count[1m])"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   Press Enter to continue to teardown...${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read

# Kill port-forwards before teardown
cleanup_port_forwards

# ─────────────────────────────────────────────────────────────────────────────
# Phase 4 – Teardown
# Objective: Clean up all local resources.
# ─────────────────────────────────────────────────────────────────────────────
phase "[Phase 4/4] Teardown – Cleaning Up Local Resources"
./scripts/teardown.sh

echo ""
echo -e "${BOLD}====================================================${NC}"
echo -e "${GREEN}${BOLD}    Full Local Test Orchestration Complete!       ${NC}"
echo -e "${BOLD}====================================================${NC}"
success "All phases executed successfully."
