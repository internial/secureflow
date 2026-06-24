# Local Environment Setup & Verification Guide

This guide details how to build, run, and verify the **SecureFlow** platform engineering system locally.

SecureFlow supports two local run environments, each validating a different layer of the system:

| Environment | Purpose |
|---|---|
| **Docker Compose** | Validate the application itself (Spring Boot + PostgreSQL + Prometheus + Grafana) under spike load. No Kubernetes involved. |
| **Kind (Kubernetes in Docker)** | Validate Kubernetes behaviour (HPA, pod scaling, service routing, networking) under the same spike load. |

The full orchestration script (`run-locally.sh`) runs both environments back-to-back, followed by incident simulations.

---

## Prerequisites
Before running, ensure you have the following installed on your machine:
* [Docker Desktop](https://www.docker.com/products/docker-desktop/) (ensure it is running)
* [Kind](https://kind.sigs.k8s.io/) (`brew install kind`)
* [kubectl](https://kubernetes.io/docs/tasks/tools/) (`brew install kubernetes-cli`)
* [Helm](https://helm.sh/) (`brew install helm`)
* [k6](https://k6.io/) (`brew install k6`)
* [Java 21 & Maven 3.9](https://openjdk.org/) (optional, since build is containerized)

---

## Scenario A: Quick Start via Docker Compose
To spin up the entire observable stack (App, PostgreSQL, Prometheus, Grafana) in raw containers:

1. Launch Docker Compose:
   ```bash
   docker compose up --build -d
   ```
2. Verify all 4 services are running:
   ```bash
   docker compose ps
   ```
3. Access services directly on your host machine:
   * **Spring Boot API**: http://localhost:8080/api/users
   * **Actuator Health**: http://localhost:8080/actuator/health
   * **Prometheus Dashboard**: http://localhost:9090
   * **Grafana Dashboards**: http://localhost:3000 (Login: `admin` / `admin`)

To teardown the Docker Compose environment:
```bash
docker compose down -v
```

---

## Scenario B: Local Kubernetes Deployment (Kind Cluster)
To provision a local multi-node Kubernetes cluster with ingress controllers, configuration secrets, and Helm charts in a single command:

1. Run the automated bootstrap script:
   ```bash
   ./scripts/local-setup.sh
   ```
   *This script validates tools, stops Docker Compose to free local ports, spins up or reuses Kind, installs nginx ingress, builds and loads the Docker app image, provisions PostgreSQL inside Kubernetes, installs the SecureFlow Helm chart, and deploys Prometheus/Grafana.*

2. Confirm Nginx Ingress mappings:
   * The Ingress controller maps local port `8080` to the internal ClusterIP.
   * **Spring Boot API**: http://localhost:8080/api/users
   * **Actuator Health**: http://localhost:8080/actuator/health

3. Inspect running pods inside the `secureflow` namespace:
   ```bash
   kubectl get pods -n secureflow
   ```

4. Inspect monitoring by running these in separate terminals:
   ```bash
   kubectl port-forward -n monitoring svc/prometheus 9090:9090
   kubectl port-forward -n monitoring svc/grafana 3000:3000
   ```
   * **Prometheus**: http://localhost:9090
   * **Grafana**: http://localhost:3000 (`admin` / `admin`)

---

## Manual Verification (CRUD verification)

### 1. Create a User (POST)
```bash
curl -i -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice DevSecOps", "email": "alice@secureflow.local"}'
```
*Expected response: `201 Created` with created User JSON.*

### 2. Retrieve All Users (GET)
```bash
curl -i http://localhost:8080/api/users
```
*Expected response: `200 OK` returning a JSON list containing the user.*

### 3. Retrieve User by ID (GET)
```bash
curl -i http://localhost:8080/api/users/1
```
*Expected response: `200 OK` returning Alice.*

### 4. Update User details (PUT)
```bash
curl -i -X PUT http://localhost:8080/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice SRE", "email": "alice@secureflow.local"}'
```
*Expected response: `200 OK` with updated name.*

### 5. Remove User (DELETE)
```bash
curl -i -X DELETE http://localhost:8080/api/users/1
```
*Expected response: `204 No Content`.*

### 6. Missing User (GET)
```bash
curl -i http://localhost:8080/api/users/999
```
*Expected response: `404 Not Found`.*

---

## Running Load Tests

The spike test is run automatically as part of `run-locally.sh` against both environments. For manual testing:

```bash
# Run 100 VU spike test against Docker Compose (application validation)
TARGET_URL=http://localhost:8080/api/users k6 run scripts/k6-spike.js

# Run 100 VU spike test against Kind cluster (Kubernetes validation)
TARGET_URL=http://localhost:8888/api/users k6 run scripts/k6-spike.js
```

**What to verify after each run:**

| Metric | Docker Compose | Kind |
|---|---|---|
| Request Rate | ✓ | ✓ |
| CPU Usage | ✓ | ✓ |
| Memory Usage | ✓ | ✓ |
| p95 Latency | ✓ | ✓ |
| Error Rate | ✓ | ✓ |
| Pod Replica Count / HPA | — | ✓ |
| Kubernetes Service Routing | — | ✓ |
