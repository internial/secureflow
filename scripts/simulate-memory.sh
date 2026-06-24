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
echo -e "${CYAN}${BOLD}      SRE Incident Simulation: Memory Spike / Pressure ${NC}"
echo -e "${BOLD}========================================================${NC}"

echo ""
info "[Step 1] Deploying a memory stressor pod to consume 480Mi memory..."
cat <<EOF | kubectl apply -n secureflow -f -
apiVersion: v1
kind: Pod
metadata:
  name: secureflow-memory-stressor
  namespace: secureflow
  labels:
    app: memory-stressor
spec:
  containers:
  - name: stress
    image: polinux/stress:1.0.4
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "480M", "--vm-hang", "600"]
    resources:
      limits:
        memory: "512Mi"
      requests:
        memory: "256Mi"
  restartPolicy: Never
EOF

success "Stressor Pod launched successfully!"
echo "Watch pod status using: kubectl get pods -n secureflow -l app=memory-stressor"

echo ""
echo -e "${YELLOW}[Observation Guidance] What to check in Grafana / Prometheus:${NC}"
echo "1. JVM Heap / Container Memory Panel: Watch memory consumption spike above 450Mi."
echo "2. Prometheus Alert: 'MemorySpike' alert triggers after 5 minutes of sustained high usage."
echo ""
echo -e "${YELLOW}[Recovery Workflow] How to resolve the alert manually:${NC}"
echo "Simply delete the memory-stressor pod to release node memory resources:"
echo -e "${CYAN}--> kubectl delete pod secureflow-memory-stressor -n secureflow${NC}"
echo -e "${BOLD}========================================================${NC}"
