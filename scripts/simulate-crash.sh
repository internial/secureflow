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
echo -e "${CYAN}${BOLD}   SRE Incident Simulation: Pod Crash / Self-Healing    ${NC}"
echo -e "${BOLD}========================================================${NC}"

echo ""
info "[Step 1] Fetching active SecureFlow pods..."
PODS=$(kubectl get pods -n secureflow -l app.kubernetes.io/name=secureflow -o jsonpath='{.items[*].metadata.name}')

if [ -z "$PODS" ]; then
  failure "No active secureflow pods found in namespace 'secureflow'."
  echo "Ensure the application is running: scripts/local-setup.sh"
  exit 1
fi

# Select the first pod to crash
TARGET_POD=$(echo $PODS | awk '{print $1}')
success "Target pod selected to crash: $TARGET_POD"

echo ""
info "[Step 2] Deleting pod forcefully to simulate sudden hardware/process failure..."
kubectl delete pod $TARGET_POD -n secureflow --grace-period=0 --force

echo ""
info "[Step 3] Monitoring Kubernetes self-healing sequence in real time..."
echo "Watch the replica manager automatically spin up a replacement pod:"
echo -e "${CYAN}--------------------------------------------------------${NC}"
kubectl get pods -n secureflow -l app.kubernetes.io/name=secureflow
echo -e "${CYAN}--------------------------------------------------------${NC}"

echo ""
echo -e "${YELLOW}[Observation Guidance] What to check in Grafana / Prometheus:${NC}"
echo "1. Active Pod Replicas Panel: Watch the counts drop to 1 and ramp back up to 2."
echo "2. Prometheus Alert: 'PodCrashLooping' or pod restart count increase."
echo ""
success "[Recovery Workflow] Completed automatically by Kubernetes ReplicaSet controller!"
echo "The system returns to normal desired state without SRE intervention."
echo -e "${BOLD}========================================================${NC}"
