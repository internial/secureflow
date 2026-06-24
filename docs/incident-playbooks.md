# SRE Operational Incident Response Playbooks

This catalog houses standard operational procedures (SOPs) for responding to alerts generated on the **SecureFlow** platform.

---

## Playbook A: HighLatency Alert Response
**SLO Target**: p95 response time < 300ms.
**Alert Threshold**: p95 > 300ms for more than 5 minutes.

### 1. Triage & Diagnostics
1. **Locate Spike**: Open the *SecureFlow SRE Dashboard* in Grafana. Confirm whether p95 has exceeded 300ms and if the spike correlates with a sudden rise in Request Rate (RPS).
2. **Review API Performance**: Identify if specific routes (e.g. GET `/api/users`) are experiencing response delays.
3. **Trace Container Metrics**: Run `kubectl top pods -n secureflow` to check if pods are hitting CPU throttle limits.
4. **Identify Slow Queries**: Connect to PostgreSQL and analyze locks or unindexed table scans:
   ```bash
   kubectl exec -it <postgres-pod> -n secureflow -- psql -U secureflow -d secureflow -c "SELECT query, state, duration FROM pg_stat_activity;"
   ```

### 2. Mitigation Strategies
* **Scaling Out**: Scale up replicas manually if HPA is lagging:
  ```bash
  kubectl scale deployment/secureflow --replicas=5 -n secureflow
  ```
* **Resource Optimization**: Adjust memory and CPU limits in Helm `values.yaml` if container throttling is observed.

---

## Playbook B: MemorySpike Alert Response
**SLO Target**: Pod memory usage < 450Mi.
**Alert Threshold**: Container/JVM memory > 450Mi for more than 5 minutes.

### 1. Triage & Diagnostics
1. **Identify Target Pod**: Find the exact pod causing the spike using Grafana or CLI:
   ```bash
   kubectl top pods -n secureflow
   ```
2. **Trigger GC / Memory Dump**: Inspect Java JVM GC activity or heap statistics:
   ```bash
   kubectl exec -it <pod-name> -n secureflow -- jcmd 1 GC.run
   ```

### 2. Mitigation Strategies
* **Graceful Restart**: Restart the deployment to spin up clean JVM runtimes and release memory leaks:
  ```bash
  kubectl rollout restart deployment/secureflow -n secureflow
  ```
* **Heap Parameter Tuning**: Edit deployment configurations to adjust JVM GC parameters (e.g., `-XX:+UseG1GC`, `-XX:MaxRAMPercentage`).

---

## Playbook C: DeploymentFailed Alert Response
**SLO Target**: Pod health = 100% available.
**Alert Threshold**: `kube_deployment_status_replicas_unavailable` > 0 for more than 5 minutes.

### 1. Triage & Diagnostics
1. **Check Rollout State**: Find why pods are failing to bootstrap:
   ```bash
   kubectl rollout status deployment/secureflow -n secureflow
   ```
2. **Fetch Event Log**: Check for image pull errors, missing secrets, or startup failures:
   ```bash
   kubectl describe deployment secureflow -n secureflow
   ```
3. **Inspect Pod Log Details**: Check for database connection issues or Spring Boot exceptions during initialization:
   ```bash
   kubectl logs -n secureflow -l app.kubernetes.io/name=secureflow --tail=100
   ```

### 2. Mitigation Strategies
* **Rollback Immediately**: Return to the last known stable deployment tag:
  ```bash
  # Check revision numbers
  helm history secureflow -n secureflow
  # Rollback
  helm rollback secureflow <stable-revision-number> -n secureflow
  ```

---

## Playbook D: PodCrashLooping Alert Response
**SLO Target**: 0 restarts.
**Alert Threshold**: Restarts count > 3 inside 5 minutes.

### 1. Triage & Diagnostics
1. **Trace Pod Restarts**: Check restart loops:
   ```bash
   kubectl get pods -n secureflow
   ```
2. **Retrieve Exit Status**: Check why the process shut down (e.g., OOMKilled, exit code 1):
   ```bash
   kubectl get pod <pod-name> -n secureflow -o jsonpath='{.status.containerStatuses[0].lastState.terminated}'
   ```

### 2. Mitigation Strategies
* **Adjust Limits**: If OOMKilled is detected, increase pod memory limits inside Helm `values.yaml` from 512Mi to 768Mi.
* **Database Connection Pool**: Check if the app is crashing due to db thread pool starvation, and adjust JDBC pool max sizes.
* **Health Probe Tuning**: If the container is slow to boot, increase `initialDelaySeconds` on liveness probes to prevent early terminations.
