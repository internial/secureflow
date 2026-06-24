#!/bin/bash
# SecureFlow AWS Teardown Script
# Destroys all AWS resources in the correct order to avoid charges.
# Run this manually after taking screenshots — it cannot be undone.

set -e

echo "========================================================"
echo "       SecureFlow - AWS Environment Teardown            "
echo "========================================================"
echo ""
echo "⚠️  This will permanently destroy all AWS resources."
read -p "Are you sure? Type 'yes' to continue: " confirm
[ "$confirm" = "yes" ] || { echo "Aborted."; exit 1; }

echo ""
echo "[1/8] Uninstalling Helm release (removes ALB, services, pods)..."
helm uninstall secureflow -n secureflow || true

echo ""
echo "[2/8] Waiting 5 minutes for ALB to be deleted by AWS..."
sleep 300

echo ""
echo "[3/8] Deleting secureflow-budgets..."
aws cloudformation delete-stack --stack-name secureflow-budgets
aws cloudformation wait stack-delete-complete --stack-name secureflow-budgets

echo "[4/8] Deleting secureflow-ecr..."
aws cloudformation delete-stack --stack-name secureflow-ecr
aws cloudformation wait stack-delete-complete --stack-name secureflow-ecr

echo "[5/8] Deleting secureflow-rds..."
aws cloudformation delete-stack --stack-name secureflow-rds
aws cloudformation wait stack-delete-complete --stack-name secureflow-rds

echo "[6/8] Deleting secureflow-iam-irsa..."
aws cloudformation delete-stack --stack-name secureflow-iam-irsa
aws cloudformation wait stack-delete-complete --stack-name secureflow-iam-irsa

echo "[7/8] Deleting secureflow-eks..."
aws cloudformation delete-stack --stack-name secureflow-eks
aws cloudformation wait stack-delete-complete --stack-name secureflow-eks

echo "[8/8] Deleting secureflow-iam-base and secureflow-vpc..."
aws cloudformation delete-stack --stack-name secureflow-iam-base
aws cloudformation delete-stack --stack-name secureflow-vpc
aws cloudformation wait stack-delete-complete --stack-name secureflow-iam-base
aws cloudformation wait stack-delete-complete --stack-name secureflow-vpc

echo ""
echo "========================================================"
echo "    ✅ All AWS resources destroyed. No further charges.  "
echo "========================================================"
