# SRE Site Reliability Targets: SLIs, SLOs & Error Budgets

This document outlines the service level objectives (SLOs) and indicators (SLIs) for **SecureFlow**.

---

## 1. Service Level Indicators (SLIs)

SLIs quantify the performance of the SecureFlow platform.

| Indicator | Definition (SLI) | Measurement Source |
| :--- | :--- | :--- |
| **Availability** | % of HTTP requests returning `2xx` or `3xx` codes over total requests. | Prometheus: `http_server_requests_seconds_count` |
| **Latency** | p95 Response Time of HTTP requests. | Prometheus: `http_server_requests_seconds_bucket` |
| **Error Rate** | % of HTTP requests returning `5xx` error codes over total requests. | Prometheus: `http_server_requests_seconds_count{status=~"5.."}` |
| **Pod Health** | % of desired pods running and healthy. | Kube-State-Metrics: `kube_deployment_status_replicas_unavailable` |

---

## 2. Service Level Objectives (SLOs)

SLOs are the targets set for SLIs.

### SLO 1: Service Availability
* **Target**: **&ge; 99.5%** of all valid incoming HTTP API requests must return non-5xx responses over any rolling 30-day window.
* **Error Budget**: **0.5%** of total requests are permitted to fail.

### SLO 2: Request Latency
* **Target**: **&ge; 95%** of all valid incoming HTTP API requests must have response latency **< 300ms** over any rolling 30-day window.
* **Error Budget**: **5%** of requests are permitted to exceed 300ms.

### SLO 3: Pod Health
* **Target**: **100%** of desired deployment replicas must be available. Alert if availability drops below 100% for more than 2 minutes.

---

## 3. Error Budget Calculations

To demonstrate error budgets in practice, assume a baseline traffic of **10,000,000 requests per month**:

### Availability Error Budget (0.5%)
* **Allowed Failed Requests**: $10,000,000 \times 0.005 = 50,000$ failed requests per month.
* **SOP Trigger**: If failed requests exceed 35,000 (70% of budget), deployment freezes are enacted, and engineering shifts to reliability repairs.

### Latency Error Budget (5.0%)
* **Allowed Slow Requests**: $10,000,000 \times 0.05 = 500,000$ requests exceeding 300ms.
* **SOP Trigger**: If slow requests exceed 400,000 (80% of budget), performance optimization and cache layer scaling are scheduled.

---

## 4. PromQL Definitions for SLO Monitoring

Prometheus queries to display SLOs on SRE Grafana Dashboards:

### Real-Time Availability SLI
```promql
sum(rate(http_server_requests_seconds_count{status!~"5.."}[5m])) / sum(rate(http_server_requests_seconds_count[5m])) * 100
```

### Real-Time Latency SLI (p95)
```promql
histogram_quantile(0.95, sum(rate(http_server_requests_seconds_bucket[5m])) by (le))
```
