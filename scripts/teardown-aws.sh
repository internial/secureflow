#!/bin/bash
# SecureFlow AWS Teardown Script
# Destroys all AWS resources in the correct order to avoid charges.

set -e

echo "========================================================"
echo "       SecureFlow - AWS Environment Teardown            "
echo "========================================================"
echo ""
echo "⚠️  This will permanently destroy all AWS resources."

# Prompts for confirmation unless non-interactive (e.g. piped or -y flag)
if [ -t 0 ]; then
  read -p "Are you sure? Type 'yes' to continue: " confirm
  [ "$confirm" = "yes" ] || { echo "Aborted."; exit 1; }
fi

echo ""
echo "[1/6] Uninstalling Helm release (removes ALB, services, pods)..."
helm uninstall secureflow -n secureflow || true

echo ""
echo "[2/6] Force-deleting ECR repository to clean up images..."
aws ecr delete-repository --repository-name secureflow --force || true

echo ""
echo "[3/6] Initiating parallel deletion of secureflow-budgets, secureflow-ecr, secureflow-rds, and secureflow-iam-irsa..."
aws cloudformation delete-stack --stack-name secureflow-budgets
aws cloudformation delete-stack --stack-name secureflow-ecr
aws cloudformation delete-stack --stack-name secureflow-rds
aws cloudformation delete-stack --stack-name secureflow-iam-irsa

echo "Waiting for budgets, ECR, RDS, and IRSA stacks to be completely deleted..."
aws cloudformation wait stack-delete-complete --stack-name secureflow-budgets || true
aws cloudformation wait stack-delete-complete --stack-name secureflow-ecr || true
aws cloudformation wait stack-delete-complete --stack-name secureflow-rds || true
aws cloudformation wait stack-delete-complete --stack-name secureflow-iam-irsa || true
echo "✅ Budgets, ECR, RDS, and IRSA stacks deleted."

echo ""
echo "[4/6] Initiating deletion of secureflow-eks (EKS Cluster)..."
aws cloudformation delete-stack --stack-name secureflow-eks

echo "Waiting for EKS stack deletion (this takes ~10-15 minutes)..."
aws cloudformation wait stack-delete-complete --stack-name secureflow-eks
echo "✅ EKS stack deleted."

echo ""
echo "[5/6] Initiating parallel deletion of secureflow-iam-base and secureflow-vpc..."
aws cloudformation delete-stack --stack-name secureflow-iam-base
aws cloudformation delete-stack --stack-name secureflow-vpc

echo "Waiting for IAM Base and VPC stacks to be completely deleted..."
aws cloudformation wait stack-delete-complete --stack-name secureflow-iam-base
aws cloudformation wait stack-delete-complete --stack-name secureflow-vpc
echo "✅ IAM Base and VPC stacks deleted."

echo ""
echo "========================================================"
echo "    ✅ All AWS resources destroyed. No further charges.  "
echo "========================================================"
