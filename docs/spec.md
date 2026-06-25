# SECUREFLOW — AI IDE FULL REPOSITORY GENERATION PROMPT
# Augmented & Clarified — Ready for Cursor / Windsurf / Copilot

You are generating a complete production-style DevOps / DevSecOps / SRE portfolio project called SecureFlow.

You must create the entire repository inside the current workspace.

DO NOT ask questions about decisions already answered in this spec. DO NOT pause on matters of preference or style. DO NOT generate partial output. DO NOT over-engineer beyond this specification. IF you encounter a genuine conflict or missing detail that would cause you to make a silent wrong assumption, flag it briefly and state what assumption you are making so the user can correct it.

------------------------------------------------------------
PROJECT GOAL
------------------------------------------------------------
Build a cloud-native platform engineering system with:
- Spring Boot User Management API (simple CRUD only)
- Docker containerization
- Kubernetes (Kind locally, EKS deployment-ready)
- Helm packaging
- GitHub Actions CI/CD with fully automated infrastructure + app deployment
- Prometheus + Grafana observability
- Security scanning (CodeQL, Trivy, Checkov, cfn-lint)
- CloudFormation AWS infrastructure definitions (deployed automatically by pipeline)
- Incident simulation scripts + SRE workflows

The application is intentionally simple. The infrastructure is the product.

------------------------------------------------------------
DEVELOPMENT STRATEGY — LOCAL FIRST
------------------------------------------------------------
PRIORITY: Everything must work locally BEFORE any AWS deployment.

Local stack:
- Docker + Docker Compose for the Spring Boot app + PostgreSQL + Prometheus + Grafana
- Kind (Kubernetes in Docker) for full cluster testing with monitoring stack
- Spring Boot app with Actuator and Micrometer Prometheus metrics
- Pre-configured Grafana dashboard for metrics visualization
- Interactive inspection pauses during workflow for metrics verification

AWS deployment is a SECOND PHASE. All CloudFormation, ECR push, and EKS
steps are fully automated via GitHub Actions after local validation is confirmed.

This two-phase approach:
  Phase 1 (Local):  Docker Compose → 100 VU spike test → monitoring pause →
                    Kind cluster → 100 VU spike test → monitoring pause →
                    incident simulations → monitoring pause → teardown
  Phase 2 (AWS):    git push → GitHub Actions → CloudFormation → ECR → EKS via Helm

------------------------------------------------------------
HARD CONSTRAINTS (NON-NEGOTIABLE)
------------------------------------------------------------
- One Spring Boot service only
- No authentication or authorization system
- No microservices architecture
- No DAST tools
- No blue/green deployments (ONLY canary via Argo Rollouts if implemented)
- No multiple environments (single environment only)
- CloudFormation only for AWS infrastructure (no Terraform, no CDK)
- HTTP only (no TLS setup anywhere)
- Managed EKS node groups assumed
- Keep everything cost minimal
- Local-first development must work fully (Docker + Kind)

------------------------------------------------------------
REPOSITORY STRUCTURE (MUST CREATE EXACTLY)
------------------------------------------------------------
secureflow/
├── app/
│   ├── src/main/java/com/secureflow/  ← Spring Boot source code
│   │   ├── SecureFlowApplication.java
│   │   ├── controller/
│   │   ├── model/
│   │   ├── repository/
│   │   └── service/
│   ├── src/main/resources/
│   │   └── application.properties    ← Actuator & Prometheus config
│   ├── pom.xml                      ← Maven dependencies
│   └── Dockerfile                   ← Multi-stage build
├── cloudformation/
│   └── (AWS infrastructure templates)
├── helm/
│   └── secureflow/
│       └── (Helm chart)
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress-local.yaml        ← nginx ingress for Kind
│   ├── ingress-eks.yaml          ← ALB ingress for EKS
│   ├── hpa.yaml
│   ├── configmap.yaml
│   └── secret.yaml
├── monitoring/
│   ├── prometheus/
│   │   ├── prometheus.yml         ← Prometheus configuration
│   │   └── alerts.yaml
│   ├── grafana/
│   │   ├── datasources/
│   │   ├── dashboards/
│   │   │   └── secureflow.json   ← Grafana dashboard provisioning
│   └── grafana-dashboard.json    ← Additional dashboard config
├── scripts/
│   ├── run-locally.sh            ← One-command local orchestration: 4 phases
│   ├── kind-cluster-setup.sh     ← One-command Kind cluster bootstrap
│   ├── teardown.sh               ← Local teardown (Kind + Docker Compose)
│   ├── teardown-aws.sh           ← AWS teardown (Helm + CloudFormation stacks)
│   ├── k6-spike.js               ← 100 VU spike test (reused in Phase 1 + 2)
│   ├── simulate-crash.sh
│   ├── simulate-memory.sh
│   ├── simulate-latency.sh
│   └── simulate-failed-deploy.sh
├── docs/
│   ├── local-setup.md
│   ├── aws-deploy.md
│   ├── incident-playbooks.md
│   └── sre-slos.md
├── kind-config.yaml              ← Kind cluster config (port mappings + ingress)
├── docker-compose.yml            ← app + postgres + prometheus + grafana
├── .github/
│   └── workflows/
│       └── ci.yml
├── README.md
└── .gitignore



------------------------------------------------------------
PHASE 1 — SPRING BOOT APPLICATION (GENERATE FULL CODE)
------------------------------------------------------------
Inside /app create a Spring Boot 3+ Maven project (Java 21):

Package:       com.secureflow
Artifact:      secureflow-api

Dependencies:
- Spring Web
- Spring Data JPA
- PostgreSQL Driver
- Spring Boot Actuator
- Micrometer Prometheus Registry

Implement:

ENTITY: User
- id    (Long, auto-generated)
- name  (String, not null)
- email (String, unique, not null)

LAYERS:
- model/User.java
- repository/UserRepository.java
- service/UserService.java
- controller/UserController.java

ENDPOINTS:
POST   /api/users         → create user (201 Created)
GET    /api/users         → get all users (200 OK, returns array)
GET    /api/users/{id}    → get user by id
PUT    /api/users/{id}    → update user
DELETE /api/users/{id}    → delete user

Return proper HTTP status codes:
- 201 Created on POST
- 200 OK on GET/PUT
- 204 No Content on DELETE
- 404 Not Found when user missing

ACTUATOR endpoints enabled:
- /actuator/health
- /actuator/prometheus

application.properties must read ALL config from environment variables:
- SPRING_DATASOURCE_URL
- SPRING_DATASOURCE_USERNAME
- SPRING_DATASOURCE_PASSWORD

Keep code clean, minimal, production-style.

------------------------------------------------------------
PHASE 2 — DOCKER
------------------------------------------------------------
Create /app/Dockerfile:
- Stage 1: Maven build (maven:3.9-eclipse-temurin-21-alpine)
- Stage 2: Runtime (eclipse-temurin:21-jre-alpine)
- Expose port 8080
- Non-root user for security

------------------------------------------------------------
PHASE 3 — LOCAL FULL STACK (DOCKER COMPOSE)
------------------------------------------------------------
Create docker-compose.yml at repo root with ALL of the following services:

1. app          — Spring Boot (built from ./app/Dockerfile)
2. postgres     — postgres:15-alpine
3. prometheus   — prom/prometheus (config from ./monitoring/prometheus/)
4. grafana      — grafana/grafana (provisioned dashboards from ./monitoring/grafana/)

Environment variables for app service:
- SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/secureflow
- SPRING_DATASOURCE_USERNAME=secureflow
- SPRING_DATASOURCE_PASSWORD=secureflow

Postgres environment:
- POSTGRES_DB=secureflow
- POSTGRES_USER=secureflow
- POSTGRES_PASSWORD=secureflow

Exposed ports (host:container):
- app:       8080:8080
- postgres:  5432:5432
- prometheus: 9090:9090
- grafana:   3000:3000

Purpose: `docker compose up` must bring up the full observable stack locally.

------------------------------------------------------------
PHASE 4 — KIND CLUSTER CONFIG
------------------------------------------------------------
Create kind-config.yaml at repo root:

- Single control-plane node
- Worker node with ingress-ready labels
- Port mappings:
    hostPort 8080 → containerPort 80  (HTTP ingress)
    hostPort 8443 → containerPort 443 (future TLS, no-op for now)

------------------------------------------------------------
PHASE 5 — KUBERNETES MANIFESTS
------------------------------------------------------------
Create resources in /k8s:

deployment.yaml:
- image: secureflow-api:latest (overridable)
- 2 replicas
- resource requests: cpu 100m, memory 256Mi
- resource limits: cpu 500m, memory 512Mi
- readinessProbe on /actuator/health
- livenessProbe on /actuator/health
- env vars from ConfigMap + Secret

service.yaml:
- ClusterIP
- port 80 → targetPort 8080

ingress-local.yaml:
- ingressClassName: nginx
- host: localhost
- path: /api → service:80

ingress-eks.yaml:
- ingressClassName: alb
- annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip

hpa.yaml:
- minReplicas: 2
- maxReplicas: 5
- CPU target: 60%

configmap.yaml:
- SPRING_DATASOURCE_URL

secret.yaml:
- SPRING_DATASOURCE_USERNAME (base64)
- SPRING_DATASOURCE_PASSWORD (base64)

------------------------------------------------------------
PHASE 6 — HELM
------------------------------------------------------------
Create Helm chart in /helm/secureflow:

Chart.yaml:
- name: secureflow
- version: 0.1.0
- appVersion: latest

values.yaml must expose:
- image.repository
- image.tag
- replicaCount
- db.url
- db.username
- db.password
- hpa.minReplicas
- hpa.maxReplicas
- ingress.enabled
- ingress.className  (nginx for local, alb for EKS)
- ingress.host

Templates:
- deployment.yaml
- service.yaml
- ingress.yaml
- hpa.yaml
- configmap.yaml
- secret.yaml

values-local.yaml:
- ingress.className: nginx
- ingress.host: localhost
- db.url: jdbc:postgresql://postgres:5432/secureflow

values-eks.yaml:
- ingress.className: alb
- ingress.host: "" (empty — ALB does not require a host header)
- image.repository: INJECTED_BY_PIPELINE
- db.url: INJECTED_BY_PIPELINE
- All real values are injected at deploy time by GitHub Actions from CloudFormation outputs.
  Do not set real values here manually.

------------------------------------------------------------
PHASE 7 — OBSERVABILITY
------------------------------------------------------------
Prometheus config in /monitoring/prometheus/prometheus.yml:
- Scrape Spring Boot app at /actuator/prometheus every 15s

Grafana provisioning in /monitoring/grafana/:
- datasources/datasource.yml  — auto-provision Prometheus datasource
- dashboards/dashboard.yml    — auto-provision dashboard loader
- dashboards/secureflow.json  — dashboard with panels:
    1. Request rate (requests/sec)
    2. p95 latency (histogram_quantile 0.95)
    3. Error rate (5xx/total)
    4. JVM CPU usage
    5. JVM memory usage
    6. Pod replica count

Grafana default login: admin / admin

Monitoring port configuration:
- Docker Compose: Prometheus 9090, Grafana 3000
- Kind Cluster:   Prometheus 9091, Grafana 3001 (offset to avoid conflicts)

------------------------------------------------------------
PHASE 8 — CI/CD (GITHUB ACTIONS)
------------------------------------------------------------
Create .github/workflows/ci.yml:

Trigger: push to main, pull_request to main

Jobs in order (main branch push only for deployment jobs):

1. git-secrets          — scan for leaked credentials
2. build-and-test       — Java 21, mvn clean verify, upload test results
3. codeql               — static analysis for Java vulnerabilities
4. checkov-cfnlint      — Checkov (security) + cfn-lint (template syntax) on /cloudformation
                           cfn-lint: .cfnlintrc.yaml ignores catalog rules (E3062, W3691);
                           CI fails only on cfn-lint errors, not warnings
5. deploy-infrastructure — CloudFormation stacks in dependency order (see Phase 9)
                           On failure: prints failed resources + stack events (not just ROLLBACK_COMPLETE)
                           Stops on ROLLBACK_COMPLETE with delete-stack instructions
                           Skips stacks in unexpected states; updates stacks that already exist
                           Fetches RDS endpoint from stack output automatically
                           Outputs: rds-endpoint, oidc-url
6. docker-build-push    — Build + push to ECR (tagged with github.sha + latest)
7. trivy                — Container scan on ECR image, fail on HIGH/CRITICAL
8. deploy-to-eks        — Helm upgrade --install to EKS
                           RDS endpoint injected from deploy-infrastructure outputs
                           ALB DNS fetched from kubectl get ingress after deploy
                           No manual RDS_ENDPOINT or ALB_DNS secrets needed

Required GitHub Secrets:
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY
- AWS_ACCOUNT_ID
- AWS_REGION
- NOTIFICATION_EMAIL (for budget alerts)

NOT required as secrets (fetched automatically by pipeline):
- RDS_ENDPOINT  — queried from secureflow-rds CloudFormation stack output
- ALB_DNS       — queried from kubectl get ingress after Helm deploy

------------------------------------------------------------
PHASE 9 — CLOUD INFRASTRUCTURE (CLOUDFORMATION)
------------------------------------------------------------
Create templates in /cloudformation:

vpc.yaml:
- VPC with CIDR 10.0.0.0/16
- 2 public subnets, 2 private subnets
- Internet Gateway, NAT Gateway, route tables

iam-base.yaml:
- EKS cluster IAM role
- EKS node group IAM role

eks.yaml:
- EKS cluster (Kubernetes 1.35)
- Managed node group: t3.medium/t3a.medium Spot Instances, min 1, max 3, desired 2
- CapacityType: SPOT
- Output: ClusterName, ClusterEndpoint, OIDCIssuerURL, ClusterSecurityGroupId

iam-irsa.yaml:
- IRSA role for app pods
- Requires OIDCIssuerURL from eks.yaml (deployed after EKS)

rds.yaml:
- PostgreSQL 17.5, db.t3.micro, single AZ
- Private subnets only
- Security group: allow 5432 from EKS node security group only
- SkipFinalSnapshot: true (cost control)
- Output: RDSEndpoint

ecr.yaml:
- ECR repository: secureflow
- Scan on push enabled
- Lifecycle policy: keep last 10 images

budgets.yaml:
- $2, $5, $10 actual + $15 forecasted alerts
- SNS topic + email notifications
- Parameter: NotificationEmail (injected from NOTIFICATION_EMAIL secret)

Deployment order (handled automatically by deploy-infrastructure job):
1. vpc.yaml
2. iam-base.yaml
3. eks.yaml
4. iam-irsa.yaml  (OIDC URL fetched from eks.yaml output)
5. rds.yaml
6. ecr.yaml
7. budgets.yaml

NOTE: iam.yaml is split into iam-base.yaml and iam-irsa.yaml to avoid circular
dependency — IRSA requires the OIDC URL which only exists after EKS deploys.

------------------------------------------------------------
PHASE 10 — LOAD TESTING (K6)
------------------------------------------------------------
scripts/k6-spike.js:
- 100 virtual users
- Ramp up: 30 seconds
- Hold:    60 seconds
- Ramp down: 30 seconds
- Total duration: 2 minutes
- Purpose: reused in both local environments and AWS post-deploy

The same test validates different layers depending on environment:
- Docker Compose: validates application behaviour (request rate, latency, errors, CPU, memory)
- Kind / EKS:     validates Kubernetes behaviour (all of the above + HPA scaling, pod replica count)

NOTE: k6-baseline.js has been removed. k6-spike.js is the single reusable load test.

------------------------------------------------------------
PHASE 11 — LOCAL ORCHESTRATION
------------------------------------------------------------
scripts/run-locally.sh — 4-phase end-to-end local validation:

Phase 1 – Docker Compose (Application Validation):
- docker compose down + up --build
- Health checks: /actuator/health and /api/users
- Run 100 VU spike test (k6-spike.js) against http://localhost:8080/api/users
- Pause for manual Grafana/Prometheus inspection
- Verify: request rate, CPU, memory, p95 latency, error rate
- Purpose: validate application, NOT Kubernetes

Phase 2 – Kind Kubernetes (Kubernetes Validation):
- docker compose down
- kind-cluster-setup.sh
- Health checks: /actuator/health and /api/users via port-forward
- Set up monitoring port-forwards (Prometheus 9091, Grafana 3001)
- Run same 100 VU spike test against http://localhost:8888/api/users
- Pause for manual inspection
- Verify: all Phase 1 metrics + pod replica count + HPA activity
- Purpose: validate Kubernetes, not the application

Phase 3 – Incident Simulations (Observability Validation):
- simulate-crash.sh
- simulate-memory.sh (cleanup stressor pod after)
- simulate-failed-deploy.sh
- Automated metrics collection via check-monitoring.sh
- Pause for manual inspection
- Verify: alerts, self-healing, memory spike, failed deploy, recovery
- Purpose: validate observability, alerting, and recovery

Phase 4 – Teardown:
- cleanup port-forwards
- teardown.sh

scripts/teardown.sh — local teardown:
- helm uninstall secureflow
- kubectl delete namespace secureflow
- kind delete cluster --name secureflow
- docker compose down -v
- Print: "Local environment fully destroyed"

scripts/teardown-aws.sh — AWS teardown (run manually after screenshots):
- Confirmation prompt before proceeding
- helm uninstall secureflow -n secureflow
- Wait 5 minutes for ALB deletion
- Delete CloudFormation stacks in reverse order with waits:
  secureflow-budgets → secureflow-ecr → secureflow-rds →
  secureflow-iam-irsa → secureflow-eks → secureflow-iam-base → secureflow-vpc
- Print: "All AWS resources destroyed. No further charges."
- Total teardown time: ~33 minutes

------------------------------------------------------------
PHASE 12 — INCIDENT SIMULATIONS
------------------------------------------------------------
scripts/simulate-crash.sh:
- Forcefully delete a running pod (--force --grace-period=0)
- Show Kubernetes self-healing
- Expected alert: PodCrashLooping (requires >3 restarts in 5m to fire)

scripts/simulate-memory.sh:
- Deploy polinux/stress pod consuming 480Mi for 600s
- Expected alert: MemorySpike (requires sustained 5m to fire)
- Recovery: delete the stressor pod

scripts/simulate-latency.sh:
- Inject 500ms delay via tc inside pod
- Requires NET_ADMIN capability — may not work in standard Kind
- Expected alert: HighLatency
- NOTE: not included in run-locally.sh due to NET_ADMIN requirement

scripts/simulate-failed-deploy.sh:
- Deploy broken image tag (broken-v9.9.9) via Helm
- Show ErrImagePull / ImagePullBackOff
- Recovery: helm rollback secureflow 1
- Expected: DeploymentFailed alert (requires 5m to fire)

Alert firing note: all alerts require for: 5m of sustained condition.
Short simulations will not trigger alerts — this is by design to prevent
alert storms from transient blips.

------------------------------------------------------------
PHASE 13 — SRE + RELIABILITY
------------------------------------------------------------
docs/sre-slos.md:

SLOs:
- Availability ≥ 99.5%
- p95 latency < 300ms
- Error rate < 1%
- Pod health = 100%

Prometheus alert rules (/monitoring/prometheus/alerts.yaml):
- HighLatency:       p95 > 300ms for 5m
- HighErrorRate:     error rate > 1% for 5m
- PodCrashLooping:  restarts > 3 in 5m
- MemorySpike:      container memory > 450Mi for 5m
- DeploymentFailed: replicas_unavailable > 0 for 5m
- HighCPU:          CPU > 80% for 5m

------------------------------------------------------------
COST CONTROL RULES
------------------------------------------------------------
- Always develop and test locally first (Docker Compose + Kind)
- Only deploy to AWS to capture screenshots/demo evidence
- After AWS demo: run scripts/teardown-aws.sh immediately
- Single EKS cluster, single AZ RDS, no NAT redundancy
- EKS nodes use Spot Instances (70-90% cost savings vs On-Demand)
- Budget alarms: $2, $5, $10 actual + $15 forecasted
- Normal 2-3 hour demo session costs ~$0.50-1.00 with Spot Instances

------------------------------------------------------------
FINAL RULES
------------------------------------------------------------
- Keep application intentionally simple — CRUD only, no auth, no extras
- Do NOT add features outside this specification
- Prioritize correctness and runnability over cleverness
- Everything must be runnable end-to-end locally before AWS steps
- All AWS infrastructure must be destroyable via scripts/teardown-aws.sh

