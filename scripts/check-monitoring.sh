#!/bin/bash
set -Eeuo pipefail

# SecureFlow Monitoring Check Script
# Queries Prometheus API for key metrics and alert status
# Usage: ./scripts/check-monitoring.sh [prometheus_url]
# Default Prometheus URL: http://localhost:9090

PROMETHEUS_URL="${1:-http://localhost:9090}"
TIME_RANGE="5m"

# Color formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}====================================================${NC}"
echo -e "${CYAN}${BOLD}  SecureFlow Monitoring Check${NC}"
echo -e "${CYAN}  Prometheus: $PROMETHEUS_URL${NC}"
echo -e "${CYAN}  Time Range: $TIME_RANGE${NC}"
echo -e "${BOLD}====================================================${NC}"
echo ""

# Function to query Prometheus
query_prometheus() {
    local query="$1"
    local description="$2"
    echo -e "${CYAN}📊 $description${NC}"
    echo "   Query: $query"

    response=$(curl -s -G "$PROMETHEUS_URL/api/v1/query" \
        --data-urlencode "query=$query" \
        --data-urlencode "time=$(date +%s)")

    if echo "$response" | grep -q '"status":"success"'; then
        value=$(echo "$response" | jq -r '.data.result[0].value[1] // "N/A"')
        echo -e "   ${GREEN}✓${NC} Value: $value"
    else
        echo -e "   ${RED}✗${NC} Query failed"
    fi
    echo ""
}

# Function to check alert status
check_alerts() {
    echo -e "${YELLOW}🚨 Active Alerts${NC}"
    response=$(curl -s "$PROMETHEUS_URL/api/v1/alerts")

    if echo "$response" | grep -q '"status":"success"'; then
        alert_count=$(echo "$response" | jq -r '.data.alerts | length')
        echo "   Total alerts: $alert_count"

        firing=$(echo "$response" | jq -r '.data.alerts[] | select(.state=="firing") | "\(.labels.alertname): \(.annotations.summary)"')
        if [ -n "$firing" ]; then
            echo -e "   ${RED}🔥 FIRING:${NC}"
            echo "$firing" | while read -r line; do
                echo "      - $line"
            done
        else
            echo -e "   ${GREEN}✅${NC} No firing alerts"
        fi

        pending=$(echo "$response" | jq -r '.data.alerts[] | select(.state=="pending") | "\(.labels.alertname)"')
        if [ -n "$pending" ]; then
            echo -e "   ${YELLOW}⏳ PENDING:${NC}"
            echo "$pending" | while read -r line; do
                echo "      - $line"
            done
        fi
    else
        echo -e "   ${RED}✗${NC} Failed to fetch alerts"
    fi
    echo ""
}

# Function to check targets
check_targets() {
    echo -e "${BLUE}🎯 Prometheus Targets${NC}"
    response=$(curl -s "$PROMETHEUS_URL/api/v1/targets")

    if echo "$response" | grep -q '"status":"success"'; then
        echo "$response" | jq -r '.data.activeTargets[] | "\(.labels.job) - \(.health): \(.lastError // "OK")"' | while read -r line; do
            if echo "$line" | grep -q "up"; then
                echo -e "   ${GREEN}✅${NC} $line"
            else
                echo -e "   ${RED}✗${NC} $line"
            fi
        done
    else
        echo -e "   ${RED}✗${NC} Failed to fetch targets"
    fi
    echo ""
}

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo -e "${RED}✗${NC} 'jq' is required but not installed. Install with: brew install jq (macOS) or apt install jq (Linux)"
    exit 1
fi

# Check if Prometheus is accessible
if ! curl -s "$PROMETHEUS_URL/-/healthy" > /dev/null; then
    echo -e "${RED}✗${NC} Cannot reach Prometheus at $PROMETHEUS_URL"
    echo "   Ensure port-forward is running: kubectl port-forward -n monitoring svc/prometheus 9091:9090 (for Kind) or 9090:9090 (for Docker Compose)"
    exit 1
fi

# Run checks
check_targets
check_alerts

# Key metrics from Grafana dashboard
query_prometheus "rate(http_server_requests_seconds_count[1m])" "Request Rate (req/s)"
query_prometheus "histogram_quantile(0.95, rate(http_server_requests_seconds_bucket[1m]))" "p95 Latency (s)"
query_prometheus "rate(http_server_requests_seconds_count{status=~\"5..\"}[1m]) / rate(http_server_requests_seconds_count[1m])" "Error Rate"
query_prometheus "rate(jvm_cpu_usage[1m]) * 100" "JVM CPU Usage (%)"
query_prometheus "jvm_memory_used_bytes" "JVM Memory Usage (bytes)"
query_prometheus "kube_deployment_status_replicas_available" "Pod Replica Count"

echo -e "${BOLD}====================================================${NC}"
echo -e "${GREEN}${BOLD}  Monitoring Check Complete${NC}"
echo -e "${BOLD}====================================================${NC}"
