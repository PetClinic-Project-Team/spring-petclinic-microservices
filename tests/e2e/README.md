# E2E Test Suite — Spring PetClinic Microservices

**Author:** P9 — QA & Demo Lead  
**Last Updated:** 2026-05-20

This folder contains the automated end-to-end test suite for the Spring PetClinic Microservices system running on AWS EKS. The tests validate infrastructure, service health, API behaviour, observability stack, and the GenAI chatbot.

---

## Prerequisites

Before running any script, ensure the following are available on your machine:

| Tool | Purpose | Check |
|------|---------|-------|
| `kubectl` | Kubernetes CLI | `kubectl version --client` |
| `curl` | HTTP requests | `curl --version` |
| `python3` | JSON parsing in scripts | `python3 --version` |
| AWS credentials | EKS cluster access | `aws sts get-caller-identity` |
| EKS kubeconfig | kubectl cluster access | `kubectl get nodes` |

Configure kubeconfig if not already done:
```bash
aws eks update-kubeconfig --region us-east-1 --name petclinic-cluster
```

---

## Scripts Overview

### `run-all-tests.sh` — Master Test Runner
Runs all 4 test suites in sequence and prints a final summary.

```bash
# Run with gateway URL
bash tests/e2e/run-all-tests.sh http://<GATEWAY_URL>

# Or export GW_IP first and run
export GW_IP=$(kubectl get svc api-gateway -n spring-petclinic \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
bash tests/e2e/run-all-tests.sh http://$GW_IP
```

**Duration:** ~80 seconds  
**Output:** Suite-level PASS/FAIL summary + saves report to `docs/test-run-report.txt`

---

### `k8s-validation.sh` — Infrastructure Validation
Validates the Kubernetes cluster state — nodes, pods, services, LoadBalancer, secrets.

```bash
bash tests/e2e/k8s-validation.sh
```

**Test cases covered:** TC-INF-001 to TC-INF-007, TC-DB-003  
**Duration:** ~20 seconds  
**No arguments required** — reads directly from the cluster.

What it checks:
- All EKS nodes are in `Ready` state
- Namespace `spring-petclinic` exists and is `Active`
- All 16 pods are in `Running` state
- No pods in `CrashLoopBackOff`, `Error`, or `Pending`
- All expected services exist
- API Gateway has a LoadBalancer hostname assigned
- No `OOMKilled` events in the namespace
- Database credentials secret `petclinic-db-secret` exists

---

### `health-check.sh` — Service Health Checks
Port-forwards to each microservice and hits the `/actuator/health` endpoint.

```bash
bash tests/e2e/health-check.sh
```

**Test cases covered:** TC-CFG-001, TC-CFG-002, TC-DIS-001, TC-DIS-002, TC-VET-003, TC-VST-004  
**Duration:** ~45 seconds  
**No arguments required** — uses port-forward to reach ClusterIP services.

What it checks:
- Config Server health returns HTTP 200
- Config Server is serving the `customers-service/docker` profile
- Discovery Server (Eureka) is accessible at port 8761
- All 4 microservices are registered in Eureka: CUSTOMERS-SERVICE, VETS-SERVICE, VISITS-SERVICE, API-GATEWAY
- Vets Service, Visits Service, and Customers Service actuator health returns `UP`

---

### `api-tests.sh` — API End-to-End Tests
Makes real HTTP calls through the AWS LoadBalancer to test all API routes and business logic.

```bash
# Pass gateway URL as argument
bash tests/e2e/api-tests.sh http://<GATEWAY_URL>

# Or using GW_IP environment variable
bash tests/e2e/api-tests.sh http://$GW_IP
```

**Test cases covered:** TC-GW-001 to TC-GW-004, TC-CST-001 to TC-CST-006, TC-VET-001 to TC-VET-002, TC-VST-001 to TC-VST-003, TC-GENAI-003  
**Duration:** ~30 seconds

What it checks:
- API Gateway routes correctly to customers, vets, and visits services
- Owner list returns seed data (non-empty)
- New owner can be created (POST returns HTTP 201)
- Owner response contains `pets` array
- 6 pet types are returned
- Vet list returns 6 vets with specialties
- Visit can be created and persists across subsequent GET
- GenAI chatbot returns AI-generated response via API Gateway

> **Note on TC-CST-004:** This test checks that a missing owner returns HTTP 404. The upstream Spring PetClinic application returns HTTP 200 with an empty body instead. This is a known upstream behaviour (DEF-003) and is logged as `[KNOWN DEFECT]` — it does not count as a test failure.

---

### `monitoring-check.sh` — Observability Stack Validation
Validates that Prometheus, Grafana, and Zipkin are running and accessible.

```bash
bash tests/e2e/monitoring-check.sh
# or
./tests/e2e/monitoring-check.sh
```

**Test cases covered:** TC-OBS-001, TC-OBS-002, TC-OBS-003, TC-OBS-005  
**Duration:** ~20 seconds  
**No arguments required.**

What it checks:
- Prometheus is accessible via port-forward on `localhost:9090` (HTTP 200 or 302)
- Prometheus has at least 1 active scrape target in `up` state
- Grafana pod is running and accessible via port-forward on `localhost:3000`
- Zipkin pod exists in the namespace

> **Note:** Prometheus and Grafana are `ClusterIP` services — they are not publicly exposed. The script automatically sets up port-forwards and tears them down on exit. While the script runs, you can also open `http://localhost:9090` and `http://localhost:3000` in a browser.
>
> Grafana login: `admin` / `petclinic123`

---

### `chaos-demo.sh` — Kubernetes Self-Healing Demo
Deletes a running pod and watches Kubernetes automatically schedule a replacement. Used as a live demo step.

```bash
# Default target: api-gateway
./tests/e2e/chaos-demo.sh

# Target a specific service
./tests/e2e/chaos-demo.sh customers-service
./tests/e2e/chaos-demo.sh vets-service
```

**Duration:** ~30 seconds to see full recovery  
**Safe to run:** API Gateway runs 2 replicas — deleting one pod does not cause downtime.

What it does:
1. Shows the current pod state for the target service
2. Deletes the first running pod
3. Watches (`-w`) as Kubernetes detects the deletion and schedules a replacement
4. Press `Ctrl+C` once the new pod reaches `Running` state

> **Expected result:** New pod reaches `Running` state within 30 seconds.

---

## Understanding the Output

| Prefix | Meaning |
|--------|---------|
| `[PASS]` | Test passed — behaviour is as expected |
| `[FAIL]` | Test failed — investigate before demo |
| `[KNOWN DEFECT]` | Known upstream bug — documented, not blocking |
| `[INFO]` | Informational — no pass/fail judgement |

---

## Quick Run — All Tests

```bash
# Step 1: Get the gateway URL
export GW_IP=$(kubectl get svc api-gateway -n spring-petclinic \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Step 2: Run everything
bash tests/e2e/run-all-tests.sh http://$GW_IP
```

Expected final output when system is healthy:
```
  Test Suites:
    [PASS] Infrastructure Validation (TC-INF-*)
    [PASS] Service Health Checks (TC-CFG-*, TC-DIS-*, TC-VET-003, TC-VST-004)
    [PASS] API End-to-End Tests (TC-GW-*, TC-CST-*, TC-VET-*, TC-VST-*)
    [PASS] Observability Stack (TC-OBS-001, TC-OBS-002, TC-OBS-003, TC-OBS-005)

  ALL 4 SUITES PASSED
```

---

## Related Documents

| Document | Location | Purpose |
|----------|----------|---------|
| Test Cases | `docs/test-cases.md` | Full test plan — 47 test cases across 10 modules |
| Test Results | `docs/test-results.md` | Execution history — Round 1 through Round 4 |
| Demo Script | `docs/demo-script.md` | Step-by-step live demo guide (7 minutes) |
