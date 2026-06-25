# SecureFlow: Lessons Learned

## Overview

Building a complete DevOps / DevSecOps / SRE platform on AWS EKS was a
large undertaking spanning application development, infrastructure as
code, CI/CD pipelines, security scanning, observability, and incident
response. This document captures the real problems encountered and how
they were resolved.

---

## 1. AWS Load Balancer Controller Was Missing

**Problem:** The Kubernetes Ingress resource was deployed but the ALB
never provisioned. The ingress remained in a pending state for hours.

**Root cause:** The AWS Load Balancer Controller (the component that
translates Kubernetes Ingress resources into real AWS ALBs) was never
installed on the EKS cluster. The CloudFormation stack created the IAM
role and policy for it, but the Helm chart deployment step had not been
added to the infrastructure pipeline.

**Fix:** Installed the controller via Helm into the `kube-system`
namespace with the correct IAM role annotation. The command pointed the
controller at the right cluster, region, and VPC. Once deployed, the
ALB was provisioned within seconds.

**Lesson:** A CloudFormation stack for IAM permissions is not enough.
The actual controller software must be deployed on the cluster. The
infrastructure pipeline needs an explicit Helm install step for cluster
add-ons.

---

## 2. OIDC Provider Was Not Registered in IAM

**Problem:** The EKS cluster was created but IAM roles for service
accounts (IRSA) were not working. Any pod trying to assume an IAM role
failed silently.

**Root cause:** EKS requires an OIDC identity provider in IAM so that
Kubernetes service accounts can assume IAM roles. The CloudFormation
stack created the role and policy, but the OIDC provider itself was
never registered.

**Fix:** Retrieved the cluster OIDC issuer URL from the EKS cluster
description and created the IAM OpenID Connect provider matching that
URL with the correct thumbprint.

**Lesson:** IRSA has three prerequisites: the OIDC provider in IAM, the
service account annotation in Kubernetes, and the IAM role trust policy.
Missing any one breaks the chain.

---

## 3. Orphaned Classic ELB Blocked VPC Deletion

**Problem:** During teardown, the VPC CloudFormation stack failed to
delete. It reported that the public subnets had dependencies and could
not be removed.

**Root cause:** The ALB Ingress created a load balancer that the
Helm uninstall step (which ran first) did not fully clean up. AWS
internally created it as a Classic ELB (not an ALB), and the
corresponding elastic network interfaces remained attached to the
subnets even after the load balancer appeared to be gone. These ENIs
retained public IP associations, which prevented the internet gateway
from being detached and the subnets from being deleted.

**Fix:** Found the Classic ELB by name using the ELB v1 API (the v2
API did not list it). Deleted it, and the ENIs were released
automatically within seconds. The VPC stack deletion then completed.

**Lesson:** Always verify load balancer cleanup after Helm uninstall.
Use both ELB v1 and v2 APIs to list remaining resources. Orphaned ENIs
are a common AWS cleanup issue that can cascade into stuck stack
deletions.

---

## 4. RDS Endpoint Must Be Resolved at Deploy Time

**Problem:** The application configuration needed the RDS hostname, but
the database endpoint is not known until CloudFormation creates it.
Hardcoding it was not an option for a reproducible pipeline.

**Fix:** The CI/CD deploy job queries the CloudFormation stack outputs
at deployment time and passes the endpoint as a Helm value. No secrets
store or manual copy-paste is needed.

**Lesson:** Infrastructure outputs (RDS endpoint, cluster name, etc.)
should flow directly from CloudFormation into the deployment step.
This keeps the pipeline self-contained and repeatable.

---

## 5. Path Filtering Avoids Unnecessary Pipeline Runs

**Problem:** Every push to the repository triggered both the CI/CD
pipeline and the infrastructure pipeline. Changing a single character
in the Java source would redeploy all eight CloudFormation stacks.

**Fix:** Added path filters to both workflows. The CI pipeline only
runs when application files change (anything outside `cloudformation/`).
The infrastructure pipeline only runs when `cloudformation/` files
change. Both can run in parallel when a commit touches both areas.

**Lesson:** Path filtering is essential for any monorepo with separate
application and infrastructure code. Without it, infrastructure
deployments become a bottleneck for application changes.

---

## 6. Trivy Severity Thresholds Require Explicit Configuration

**Problem:** Trivy scans completed successfully but never failed the
pipeline regardless of what vulnerabilities were found.

**Root cause:** Trivy by default exits with code zero even when it
finds vulnerabilities. The `--exit-code 1` flag and `--severity`
threshold must be explicitly set to enforce policy.

**Fix:** Added `--exit-code 1 --severity CRITICAL,HIGH` to the Trivy
scan command. Now any critical or high severity vulnerability fails
the build.

**Lesson:** Security tools must be configured to fail in CI. A scan
that always passes is not a gate — it is a report.

---

## 7. Spring Boot Dependency Vulnerabilities Required Overrides

**Problem:** The initial build of the Spring Boot application passed
all checks, but Trivy later reported critical CVEs in
spring-webmvc, spring-core, and spring-boot itself.

**Fix:** Pinned Spring Boot to version 3.5.16 and added explicit
dependency overrides for spring-framework 6.2.11 in the Maven POM.
The overrides force Maven to use patched versions regardless of what
transitive dependencies specify.

**Lesson:** Using the latest Spring Boot version is not enough.
Transitive dependencies can pull in vulnerable older libraries.
Explicit overrides in pom.xml are necessary, and Trivy in the pipeline
catches regressions.

---

## 8. k6 Test Cleaned Up Its Own Data

**Problem:** After running the k6 spike load test, the API returned an
empty user list. The database appeared to be unused.

**Root cause:** The k6 test script performed POST, GET, and DELETE for
each iteration. Every user created was immediately deleted. This was by
design for clean test runs but made the database look pointless during
demos.

**Fix:** Created a few permanent users manually after the test to
demonstrate persistence. The test script could be modified to only
create users (without deletion) for future demo runs.

**Lesson:** Load test scripts should match their purpose. A test that
exercises full CRUD is good for validation. A demo environment may
want a separate script that leaves data behind.

---

## 9. Budget Alerts Prevent Cost Surprises

**Problem:** Without cost controls, an EKS cluster running continuously
could generate unexpected AWS charges.

**Fix:** A CloudFormation stack creates a monthly budget of 500 USD
with alert thresholds at 50% and 90%. If costs exceed either
threshold, the account email receives a notification.

**Lesson:** Budgets and alerts should be part of the infrastructure
from day one, not added after a surprise bill arrives.

---

## Untested Scenarios (Documented but Not Executed)

Two incident simulations were prepared but never run on the live
cluster.

**Memory Spike (`simulate-memory.sh`):** Deploys a stress container
that consumes 480 MB of RAM, mimicking a memory leak. The detection
mechanism is wired up — Prometheus scrapes pod metrics and Grafana
displays JVM heap usage — but the simulation was not executed long
enough for an alert to fire. The script and monitoring configuration
are ready; a future session can run it to validate end-to-end alerting.

**Failed Deployment (`simulate-failed-deploy.sh`):** Pushes a
deployment with a nonexistent container image tag. The new pod gets
stuck in `ImagePullBackoff`, simulating bad code reaching production.
The fix is a `helm rollback` to restore the last known good version.
The rollback procedure was tested manually and completed cleanly.

These scenarios remain valid for future SRE drills. They test the two
remaining failure modes not covered by the pod crash simulation:
resource exhaustion and bad deploy rollout.

## Lessons That Went Well

- **Parallel stack deletion** in the teardown script reduced total
  cleanup time by running independent stacks concurrently.

- **Commit SHA image tags** made it trivial to trace which build is
  running in each environment.

- **Secret-free deployment** using CloudFormation outputs directly
  avoided the complexity of managing a secrets store.

- **Grafana with pre-provisioned dashboards** meant observability was
  available immediately on deploy, no manual dashboard setup needed.

- **Security checks before image build** prevented vulnerable code
  from ever reaching the container registry.
