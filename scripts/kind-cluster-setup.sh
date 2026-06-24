#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/local-env.sh"
cd "${SECUREFLOW_REPO_ROOT}"

echo "========================================================"
echo "    SecureFlow - Local Kind Environment Setup           "
echo "========================================================"

for cmd in docker kind kubectl helm; do
    require_command "$cmd"
done

wait_for_docker

echo "Stopping Docker Compose stack to free local ports..."
docker compose down --remove-orphans

if kind get clusters | grep -qx secureflow; then
    echo "Kind cluster 'secureflow' already exists. Reusing it."
else
    echo "Creating Kind cluster..."
    kind create cluster --config kind-config.yaml --name secureflow
fi

kubectl config use-context kind-secureflow

echo "Installing Nginx Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "Patching nginx ingress controller to use NodePort..."
kubectl patch svc ingress-nginx-controller -n ingress-nginx -p '{"spec":{"type":"NodePort"}}'

echo "Waiting for Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=180s

echo "Building Spring Boot Docker image..."
docker build -t secureflow-api:latest ./app

echo "Loading secureflow-api:latest image into Kind cluster..."
kind load docker-image secureflow-api:latest --name secureflow

echo "Creating 'secureflow' namespace..."
kubectl create namespace secureflow --dry-run=client -o yaml | kubectl apply -f -

echo "Deploying local PostgreSQL in Kind..."
if [[ -f k8s/postgres-deployment.yaml ]]; then
    kubectl apply -f k8s/postgres-deployment.yaml -n secureflow
else
    cat <<'EOF' | kubectl apply -n secureflow -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        env:
        - name: POSTGRES_DB
          value: secureflow
        - name: POSTGRES_USER
          value: secureflow
        - name: POSTGRES_PASSWORD
          value: secureflow
        ports:
        - containerPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  ports:
  - port: 5432
  selector:
    app: postgres
EOF
fi

echo "Deploying SecureFlow application via Helm..."
helm upgrade --install secureflow ./helm/secureflow \
  --namespace secureflow \
  -f ./helm/secureflow/values-local.yaml \
  --set image.repository=secureflow-api \
  --set image.tag=latest

echo "Deploying monitoring stack (Prometheus + Grafana)..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

if [[ -f k8s/prometheus-deployment.yaml ]]; then
    kubectl apply -f k8s/prometheus-deployment.yaml -n monitoring
else
    cat <<'EOF' | kubectl apply -n monitoring -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  labels:
    app: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:v2.45.0
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus'
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus
        - name: prometheus-storage
          mountPath: /prometheus
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config
      - name: prometheus-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
spec:
  ports:
  - port: 9090
    targetPort: 9090
  selector:
    app: prometheus
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
      - job_name: 'secureflow'
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names:
                - secureflow
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
            action: keep
            regex: secureflow
          - source_labels: [__meta_kubernetes_pod_ip]
            target_label: __address__
            replacement: $1:8080
          - target_label: __metrics_path__
            replacement: /actuator/prometheus
EOF
fi

if [[ -f k8s/grafana-deployment.yaml ]]; then
    kubectl apply -f k8s/grafana-deployment.yaml -n monitoring
else
    cat <<'EOF' | kubectl apply -n monitoring -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  labels:
    app: grafana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:10.0.0
        env:
        - name: GF_SECURITY_ADMIN_USER
          value: admin
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: admin
        ports:
        - containerPort: 3000
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
      volumes:
      - name: grafana-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
spec:
  ports:
  - port: 3000
    targetPort: 3000
  selector:
    app: grafana
EOF
fi

echo "Waiting for pods to be ready..."
kubectl rollout status deployment/secureflow -n secureflow --timeout=120s
kubectl wait --for=condition=available --timeout=60s deployment/prometheus -n monitoring
kubectl wait --for=condition=available --timeout=60s deployment/grafana -n monitoring

echo ""
echo "========================================================"
echo "    Local Kind Environment Ready                        "
echo "========================================================"
echo "API via ingress: http://localhost:8080/api/users"
echo ""
echo "For monitoring access, run these in separate terminals:"
echo "  kubectl port-forward -n monitoring svc/prometheus 9091:9090"
echo "  kubectl port-forward -n monitoring svc/grafana 3001:3000"
echo ""
echo "Then open:"
echo "  Prometheus: http://localhost:9091"
echo "  Grafana:    http://localhost:3001 (admin/admin)"
