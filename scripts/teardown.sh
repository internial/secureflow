#!/bin/bash
# set -e (We don't exit on error so that the script can continue deleting even if some components are already deleted)

echo "========================================================"
echo "    SecureFlow - Starting Local Environment Teardown    "
echo "========================================================"

echo "[1/4] Uninstalling Helm chart deployment..."
helm uninstall secureflow -n secureflow || true

echo "[2/4] Deleting 'secureflow' Kubernetes namespace..."
kubectl delete namespace secureflow || true

echo "[3/4] Destroying local Kind Kubernetes cluster..."
kind delete cluster --name secureflow || true

echo "[4/4] Spinning down Docker Compose stack..."
docker compose down -v || true

echo "========================================================"
echo "      Local environment fully destroyed!                "
echo "========================================================"
