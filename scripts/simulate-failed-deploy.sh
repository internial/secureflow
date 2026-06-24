#!/bin/bash
set -e

# Color formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

success() {
    echo -e "${GREEN}✓${NC} $1"
}

failure() {
    echo -e "${RED}✗${NC} $1"
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

echo -e "${BOLD}========================================================${NC}"
echo -e "${CYAN}${BOLD}    SRE Incident Simulation: Failed Deployment / Rollback ${NC}"
echo -e "${BOLD}========================================================${NC}"

echo ""
info "[Step 1] Deploying non-existent image tag 'broken-v9.9.9' via Helm..."
helm upgrade secureflow ./helm/secureflow \
  --namespace secureflow \
  --set image.tag=broken-v9.9.9 \
  --reuse-values

echo ""
info "[Step 2] Monitoring rollout status... This will fail/hang as image doesn't exist!"
echo "Press Ctrl+C if you want to skip waiting. Waiting up to 15 seconds..."
kubectl rollout status deployment/secureflow -n secureflow --timeout=15s || {
  echo ""
  failure "Deployment is stuck in ImagePullBackOff / ErrImagePull state! Let's check status:"
}

echo -e "${CYAN}--------------------------------------------------------${NC}"
kubectl get pods -n secureflow -l app.kubernetes.io/name=secureflow
echo -e "${CYAN}--------------------------------------------------------${NC}"

echo ""
info "[Step 3] Initiating SRE rollback sequence..."
echo "Running: helm rollback secureflow 1"
# Rollback to the previous stable release
helm rollback secureflow 1 -n secureflow

echo ""
info "Checking deployment rollout status after rollback..."
kubectl rollout status deployment/secureflow -n secureflow --timeout=60s

success "Rollback completed successfully!"

echo ""
echo -e "${YELLOW}[Observation Guidance] What to check in Grafana / Prometheus:${NC}"
echo "1. Active Pod Replicas: Replicas will show 0 healthy/active pod count during failure."
echo "2. Prometheus Alert: 'DeploymentFailed' alert loop rules."
echo ""
success "[Recovery Workflow] Rolled back successfully using SRE standard 'helm rollback'!"
echo -e "${BOLD}========================================================${NC}"
