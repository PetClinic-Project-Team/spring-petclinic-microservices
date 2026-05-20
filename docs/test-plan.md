# Spring PetClinic Microservices — Test Plan

**Document Version:** 1.0  
**Author:** P9 — QA & Demo Lead  
**Date:** 2026-05-13  
**Project:** Spring PetClinic Microservices on AWS EKS  
**Repository:** https://github.com/PetClinic-Project-Team/spring-petclinic-microservices

---

## 1. Overview

This test plan defines the quality assurance strategy for the Spring PetClinic Microservices
deployment on AWS EKS. It covers all functional services, infrastructure layers, and the
observability stack, providing a structured approach to validate system correctness before
the final project presentation.

---

## 2. Scope

### 2.1 In-Scope Services

| Service             | Port  | Owner | Test Focus                              |
|---------------------|-------|-------|-----------------------------------------|
| config-server       | 8888  | P4    | Health, config serving, startup order   |
| discovery-server    | 8761  | P4    | Eureka registration, UI availability    |
| api-gateway         | 8080  | P6    | Routing, load balancer, public access   |
| customers-service   | 8081  | P5    | CRUD owners, CRUD pets                  |
| vets-service        | 8083  | P5    | Vets listing, specialty data            |
| visits-service      | 8082  | P6    | Visit scheduling, retrieval             |
| MySQL (×3)          | 3306  | P7    | Connectivity, schema, seed data         |
| Prometheus          | 9090  | P8    | Metric scraping, targets health         |
| Grafana             | 3000  | P8    | Dashboard availability, data source     |
| Zipkin              | 9411  | P8    | Trace ingestion, UI availability        |

### 2.2 Out of Scope
- GenAI service (optional extension)
- Load/stress testing beyond basic performance smoke tests
- Security penetration testing

---

## 3. Test Levels

| Level              | Tool / Approach              | When                      |
|--------------------|------------------------------|---------------------------|
| Unit               | JUnit (Maven: `mvn test`)    | Pre-deployment (local)    |
| Integration        | Maven + Spring Test          | Pre-deployment (local)    |
| Infrastructure     | `kubectl` validation scripts | Post-deployment (EKS)     |
| System / API       | `curl`-based shell scripts   | Post-deployment (EKS)     |
| End-to-End         | Browser + API combined       | Post-deployment (EKS)     |
| Smoke              | Automated runner             | After each deployment     |
| Regression         | Full suite re-run            | Before presentation       |

---

## 4. Test Types

### 4.1 Functional Testing
- Service health endpoint validation (`/actuator/health`)
- REST API correctness (CRUD operations for all entities)
- Service discovery registration verification
- API gateway routing correctness
- Database schema and seed data validation

### 4.2 Non-Functional Testing
- **Availability:** All pods in `Running` state, no `CrashLoopBackOff`
- **Resilience:** Pod restart recovery (kubectl rollout restart + re-test)
- **Startup Order:** Config → Discovery → Backend services (dependency chain)
- **Resource Limits:** Pod resource usage within defined requests/limits

### 4.3 Observability Validation
- Prometheus scraping all service `/actuator/prometheus` endpoints
- Grafana JVM dashboard rendering live data
- Zipkin receiving distributed traces on API calls

---

## 5. Test Environment

| Component       | Details                                            |
|-----------------|----------------------------------------------------|
| Cloud           | AWS EKS, region: `us-east-1`                       |
| Cluster         | `petclinic-cluster`                                |
| Namespace       | `spring-petclinic`                                 |
| ECR Registry    | `989800606347.dkr.ecr.us-east-1.amazonaws.com`     |
| Entry Point     | API Gateway LoadBalancer External IP               |
| Monitoring      | Grafana LoadBalancer IP, Prometheus ClusterIP      |
| Tracing         | Zipkin LoadBalancer IP (port 9411)                 |
| Local Access    | `kubectl port-forward` for internal services       |
| Tools Required  | `kubectl`, `curl`, `bash 3.2+`, `aws cli`          |

---

## 6. Entry Criteria

The following must be satisfied before executing this test plan:

- [ ] EKS cluster `petclinic-cluster` is active (`kubectl get nodes` shows Ready)
- [ ] All Docker images successfully built and pushed to ECR by P3
- [ ] Kubernetes namespace `spring-petclinic` exists
- [ ] All K8s manifests applied (`kubectl get deployments -n spring-petclinic`)
- [ ] MySQL databases deployed and initialized with seed data (P7)
- [ ] Prometheus and Grafana deployed (P8)
- [ ] API Gateway external IP is available

---

## 7. Exit Criteria

Testing is considered complete when:

- [ ] All test cases in `docs/test-cases.md` have a recorded outcome (PASS / FAIL / SKIP)
- [ ] Critical test cases (marked P0) are 100% passing
- [ ] High priority test cases (P1) achieve ≥ 90% pass rate
- [ ] All failures have documented root cause and resolution in `docs/test-results.md`
- [ ] Demo script has been rehearsed end-to-end at least once successfully

---

## 8. Test Approach

### 8.1 Automated Scripts
Four shell scripts under `tests/e2e/` cover all test layers:
- `k8s-validation.sh` — infrastructure state (pods, services, deployments)
- `health-check.sh` — service health endpoints via port-forward and LoadBalancer
- `api-tests.sh` — full CRUD API coverage with assertion checks
- `monitoring-check.sh` — Prometheus targets, Grafana data source, Zipkin UI

A master runner `run-all-tests.sh` executes all scripts and produces a summary report.

### 8.2 Manual Testing
Browser-based UI walkthrough covering the complete user journey:
owner creation → pet addition → visit booking → visit history review

### 8.3 GitHub Actions Integration
The workflow `.github/workflows/e2e-tests.yml` runs the automated suite on:
- Manual trigger (`workflow_dispatch`) for on-demand testing
- Pull requests targeting `develop` branch

---

## 9. Risk Register

| Risk                                        | Likelihood | Impact | Mitigation                                   |
|---------------------------------------------|------------|--------|----------------------------------------------|
| EKS nodes not ready before test run         | Medium     | High   | Run `kubectl wait` checks before test suite  |
| API Gateway IP not assigned                 | Low        | High   | Use port-forward as fallback                 |
| Config-server fails to load remote config   | Medium     | High   | Verify Git config URL and profile in logs    |
| Database not seeded (missing data.sql run)  | Medium     | Medium | Manual SQL check via kubectl exec            |
| Prometheus not scraping services            | Low        | Medium | Verify `/actuator/prometheus` on each pod    |

---

## 10. Deliverables

| Artifact                          | Location                        | Status      |
|-----------------------------------|---------------------------------|-------------|
| Test Plan                         | `docs/test-plan.md`             | Complete    |
| Test Cases                        | `docs/test-cases.md`            | Complete    |
| Demo Script                       | `docs/demo-script.md`           | Complete    |
| Automated Test Scripts            | `tests/e2e/`                    | Complete    |
| GitHub Actions E2E Workflow       | `.github/workflows/e2e-tests.yml` | Complete  |
| Test Results Report               | `docs/test-results.md`          | In Progress |

---

## 11. Roles & Responsibilities

| Role              | QA Responsibility                              |
|-------------------|------------------------------------------------|
| P9 (QA Lead)      | Test plan, test cases, demo script, execution  |
| P2 (AWS Infra)    | Provide cluster access, LoadBalancer IPs       |
| P4 (Config/Discovery) | Confirm Eureka registration of all services |
| P5, P6 (Backend)  | Confirm API endpoints are live and correct     |
| P7 (DB Admin)     | Confirm MySQL connectivity and seed data       |
| P8 (Observability)| Confirm Prometheus targets and Grafana dashboards |
