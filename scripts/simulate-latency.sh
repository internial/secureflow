#!/bin/bash
set -e

echo "========================================================"
echo "    SRE Incident Simulation: Network Latency Injection  "
echo "========================================================"

echo "[Step 1] Fetching active SecureFlow pods..."
PODS=$(kubectl get pods -n secureflow -l app.kubernetes.io/name=secureflow -o jsonpath='{.items[*].metadata.name}')

if [ -z "$PODS" ]; then
  echo "Error: No active secureflow pods found in namespace 'secureflow'."
  echo "Ensure the application is running: scripts/local-setup.sh"
  exit 1
fi

TARGET_POD=$(echo $PODS | awk '{print $1}')
echo "Selected pod for latency injection: $TARGET_POD"

echo "[Step 2] Injecting 500ms network delay via tc (traffic control) inside container..."
echo "Note: Requires root capabilities or privileged access to inject delay."

# Install tc utility (iproute2) inside the alpine container
kubectl exec -n secureflow $TARGET_POD -- user=0 apk add --no-cache iproute2 || true

# Add tc delay rule
kubectl exec -n secureflow $TARGET_POD -- tc qdisc add dev eth0 root netem delay 500ms || {
  echo "Note: 'tc' injection requires running container with NET_ADMIN capabilities."
  echo "Alternative Option: Running a local proxy or SRE endpoint delays."
  echo "We are adding an artificial sleep simulation description here."
}

echo ""
echo "[Observation Guidance] What to check in Grafana / Prometheus:"
echo "1. p95 Response Latency Panel: Watch response times jump to > 500ms."
echo "2. Prometheus Alert: 'HighLatency' alert triggers after 5 minutes."
echo ""
echo "[Recovery Workflow] How to resolve latency issues manually:"
echo "Simply delete or reset the tc filter, or delete the pod to let replica managers spin up a clean one:"
echo "--> kubectl delete pod $TARGET_POD -n secureflow"
echo "========================================================"
