# SecureFlow — DevOps, DevSecOps & SRE Portfolio Platform

## Overview

SecureFlow is a cloud-native platform engineering project that demonstrates the full DevOps, DevSecOps, and SRE lifecycle. The application is a simple Spring Boot user management API — the infrastructure, pipelines, security controls, and observability are the actual product.

Every component is designed to run locally first (Docker Compose and Kind) before touching AWS, keeping costs near zero during development.

---

## What the Pipeline Does

A single `git push main` to GitHub triggers two automated workflows that run in parallel:

### CI/CD Pipeline (App Changes)

Triggered when application or Docker files change. Runs these steps in order:

1. **Secret Scan** — Checks the entire repository for accidentally committed AWS credentials or API keys. If found, the pipeline stops immediately.
2. **Build and Test** — Compiles the Java application and runs all unit tests.
3. **CodeQL Analysis** — Scans the Java codebase for security vulnerabilities using GitHub's semantic analysis engine.
4. **Docker Build and Push** — Builds a container image and pushes it to AWS ECR, tagged with the commit ID (the full Git SHA, for example `dfdd39e6a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6`). This means every image in the registry is linked to the exact code that built it. If you see a pod running `secureflow:dfdd39e6`, you know precisely which commit produced it — no guessing whether it was built before or after a given fix. The image is also tagged as `latest`, but the SHA tag is the source of truth for traceability.
5. **Container Vulnerability Scan** — Scans the pushed image for operating system and library-level vulnerabilities. Fails on critical or high severity findings.
6. **Deploy to EKS** — Installs or upgrades the application on the EKS cluster using Helm. The database endpoint is fetched automatically from CloudFormation outputs — no manual configuration needed.

### Infrastructure Pipeline (AWS Changes)

Triggered when CloudFormation or workflow files change. Runs these steps in order:

1. **Infrastructure Security Scan** — Validates all CloudFormation templates for security misconfigurations using Checkov, and checks template syntax with cfn-lint.
2. **Deploy Infrastructure** — Creates or updates eight CloudFormation stacks in strict dependency order (see below).
3. **Install ALB Controller** — After the stacks are ready, installs the AWS Load Balancer Controller onto the EKS cluster via Helm. This controller watches for Kubernetes ingress resources and automatically provisions Application Load Balancers in AWS, so every deploy gets a public URL without manual setup.

---

## AWS Infrastructure — Deployed Automatically

All infrastructure is defined as CloudFormation templates and deployed by the pipeline. The stacks are deployed in this sequence:

| Order | Stack Name | What It Creates |
|---|---|---|
| 1 | secureflow-vpc | Virtual private cloud with public and private subnets across two availability zones, internet gateway, NAT gateway, and route tables |
| 2 | secureflow-iam-base | IAM roles for the EKS cluster and its worker nodes |
| 3 | secureflow-eks | EKS cluster running Kubernetes with a managed node group using Spot Instances (t3.medium, minimum 1, maximum 3, desired 2) |
| 4 | secureflow-iam-irsa | IAM roles for Kubernetes service accounts, linked to the cluster's OIDC provider (requires the EKS stack to exist first) |
| 5 | secureflow-alb-controller | IAM policy and IRSA role for the AWS Load Balancer Controller, allowing it to create and manage Application Load Balancers (requires the EKS OIDC URL) |
| 6 | secureflow-rds | PostgreSQL database in private subnets, accessible only from the EKS node security group. Uses a single AZ and small instance type for cost control |
| 7 | secureflow-ecr | Container registry to store application images. Scan on push is enabled, and only the ten most recent images are kept |
| 8 | secureflow-budgets | AWS Budget alerts at two, five, ten, and fifteen dollars that notify the team by email when costs approach each threshold |

The pipeline handles all dependencies automatically. For example, it waits for the VPC and IAM roles to finish before creating the EKS cluster, and fetches the OIDC URL from the EKS stack before creating the IRSA roles.

---

## How Everything Connects

The VPC and EKS cluster provide the network and compute layer. The database lives inside the private subnets and is only reachable from the cluster. The container registry stores the application images. IAM roles control what each component can access. Budget alerts protect against unexpected costs.

When the CI pipeline deploys the application, it reads the database endpoint directly from the RDS CloudFormation stack output and injects it into the Helm chart. No database endpoint secrets are stored in GitHub — everything is resolved at deploy time.

The AWS Load Balancer Controller running in the cluster watches for the Kubernetes ingress and automatically provisions an internet-facing ALB in AWS. The ALB DNS is printed at the end of the deploy step so you can immediately test the live API.

---

## Security Layers

Security checks are embedded at every stage of the pipeline:

- **git-secrets** runs first on every push to catch leaked credentials before any processing begins
- **CodeQL** analyzes the Java code for application-level vulnerabilities
- **Checkov** validates CloudFormation templates against hundreds of infrastructure security rules
- **cfn-lint** checks template syntax and enforces best practices
- **Trivy** scans the final container image for known vulnerabilities
- Any failure in any security step blocks the entire pipeline

---

## Local Development

The entire stack can run on a laptop without any AWS account. The local workflow has four phases:

1. **Docker Compose** runs the application, PostgreSQL, Prometheus, and Grafana together. A 100-user load test validates the application behavior.
2. **Kind Kubernetes** provisions a local cluster and deploys the same application. The same load test validates Kubernetes behaviors like pod scaling and service routing.
3. **Incident Simulations** inject failures into the local cluster — pod crashes, memory pressure, and broken deployments — to verify that monitoring, alerting, and recovery all work correctly.
4. **Teardown** destroys everything created locally.

Only after local validation passes would you push to GitHub to deploy to AWS.

---

## Cost Control

- Development and testing happen entirely on your laptop for free
- AWS is only used for final validation or demo evidence
- All AWS resources can be destroyed with a single script
- EKS uses Spot Instances, reducing compute costs by 70 to 90 percent
- A typical two-to-three hour demo session costs less than one dollar
- Budget alerts notify the team at two, five, ten, and fifteen dollars

---

## Stack Summary

The project uses Java 21 and Spring Boot 3 for the application. Docker and Kubernetes handle containerization and orchestration. Helm packages the application for deployment. Kind provides a local Kubernetes environment. AWS services include EKS for Kubernetes, RDS for PostgreSQL, ECR for container images, and CloudFormation for infrastructure as code. GitHub Actions orchestrates the pipelines. Prometheus and Grafana provide monitoring and visualization. k6 runs load testing. Security scanning uses Trivy, CodeQL, Checkov, cfn-lint, and git-secrets.

---

## Screenshots (Production Run)

Full-resolution PDF with all screenshots and descriptions:

- [**Production Run — Screenshots & Details**](docs/production%20run%20pics.pdf)
- [**Local Run — Screenshots & Details**](docs/local%20run%20pics.pdf)

### Load Testing (k6 Spike Test — 100 VUs)

Why: validate that the EKS cluster + ALB handle traffic spikes without errors and that HPA scales pods correctly.

Metrics measured:
- Requests per second sustained by the ALB
- Success rate (no failed requests)
- Average, p95, and p99 response latency
- HPA replica count scaling behavior under load

### What's Covered

- GitHub Actions CI/CD pipeline — all security checks passing
- GitHub Actions Infrastructure pipeline — CloudFormation deploy
- Grafana dashboards after k6 spike load test
- Grafana SRE incident simulation — pod crash & automatic self-healing
- AWS CloudFormation stacks — all 7 in CREATE_COMPLETE
- AWS EKS cluster, RDS PostgreSQL, Application Load Balancer
- Persistent users in database proving RDS works

### Additional Documents

- [Lessons learned](docs/lessons-learned.md)
- [Full project specification](docs/spec.md)
