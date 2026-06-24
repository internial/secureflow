# 🌊 SecureFlow — DevOps, DevSecOps & SRE Portfolio Platform

## What This Project Is

SecureFlow is a production-grade platform engineering project that demonstrates the full DevOps, DevSecOps, and SRE lifecycle in a single repository.

The application is intentionally simple — a Spring Boot user management API. The infrastructure, pipelines, security controls, observability, and operational workflows are the product.

---

## What I Built

**CI/CD Pipeline (GitHub Actions)**
A fully automated pipeline triggered on every `git push`. It runs security gates, builds and scans a container image, deploys AWS infrastructure via CloudFormation, and releases the application to EKS via Helm — with zero manual steps.

**AWS Infrastructure as Code (CloudFormation)**
The entire AWS environment is defined in code: VPC with public/private subnets, EKS cluster with Spot Instance node groups, RDS PostgreSQL, ECR container registry, IAM roles with least-privilege IRSA, and budget alerts. Deployed automatically by the pipeline. Destroyed with a single script.

**Kubernetes & Helm**
The application is packaged as a Helm chart and deployed to both a local Kind cluster and AWS EKS. Includes Horizontal Pod Autoscaler, readiness/liveness probes, and separate values files per environment.

**Observability Stack**
Prometheus scrapes live application metrics. Grafana dashboards are provisioned as code. Alert rules cover latency, error rate, CPU, memory, pod health, and deployment failures.

**Load Testing (k6)**
A 100 virtual user spike test validates the application under load. The same test is reused across environments — against Docker Compose to validate the application, and against Kind/EKS to validate Kubernetes scaling and HPA behaviour.

**SRE Incident Simulations**
Three scripted failure scenarios run against the live cluster: pod crash with automatic self-healing, memory pressure with spike detection, and a failed deployment with `helm rollback` recovery. Each prints step-by-step what to observe in Grafana.

**Security (Multiple Layers)**
git-secrets on commit, CodeQL static analysis on Java code, Trivy container scanning, Checkov and cfn-lint on CloudFormation templates. Every layer is gated in the pipeline — a failure blocks deployment.

**Local-First Workflow**
The entire stack runs on a laptop before anything touches AWS. Docker Compose validates the application. Kind validates Kubernetes. AWS is used only for final demo evidence, then torn down immediately to control costs.

---

**Stack:** Java 21 · Spring Boot 3 · Docker · Kubernetes · Helm · Kind · AWS EKS · RDS · ECR · CloudFormation · GitHub Actions · Prometheus · Grafana · k6 · Trivy · CodeQL · Checkov

---

## Repository Structure

```
secureflow/
├── app/                  ← Spring Boot API (source, Dockerfile, pom.xml)
├── cloudformation/       ← AWS infrastructure stacks (VPC, EKS, RDS, ECR, IAM, Budgets)
├── helm/secureflow/      ← Helm chart with values for local and EKS environments
├── monitoring/           ← Prometheus config, alert rules, Grafana dashboards
├── scripts/              ← Local orchestration, load tests, incident simulations, teardown
├── docs/                 ← AWS deployment playbook, SRE SLOs, incident playbooks
├── .github/workflows/    ← CI/CD pipeline
└── docker-compose.yml    ← Full local stack (app + postgres + prometheus + grafana)
```

---

## Prerequisites

```bash
brew install kind kubernetes-cli helm k6
```
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (must be running)
- Java 21 + Maven 3.9 (optional — build is containerized)

---

## Local Testing

```bash
./scripts/run-locally.sh
```

| Phase | Environment | Validates |
|---|---|---|
| 1 | Docker Compose | Application under 100 VU spike load |
| 2 | Kind Kubernetes | HPA, pod scaling, service routing under the same load |
| 3 | Kind Kubernetes | Alerting, self-healing, and recovery via incident simulations |
| 4 | — | Teardown |

Monitoring: Prometheus `localhost:9090` · Grafana `localhost:3000` (Docker Compose) — offset to `9091` / `3001` for Kind.

---

## AWS Deployment

Add 5 GitHub secrets (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_ACCOUNT_ID`, `AWS_REGION`, `NOTIFICATION_EMAIL`), then:

```bash
git push origin main
```

Pipeline runs end to end. `RDS_ENDPOINT` and `ALB_DNS` are resolved automatically from CloudFormation outputs. See [docs/aws-deploy.md](docs/aws-deploy.md).

---

## Teardown

```bash
./scripts/teardown.sh       # local
./scripts/teardown-aws.sh   # AWS (~33 min, confirmation required)
```

---

## Further Reading

- [Local Setup Guide](docs/local-setup.md)
- [AWS Deployment Playbook](docs/aws-deploy.md)
- [SRE SLOs](docs/sre-slos.md)
- [Incident Playbooks](docs/incident-playbooks.md)
