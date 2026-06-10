# Issue #3 — Config Server & Discovery Server (Eureka)

**Branch:** `feature/issue-3-config-discovery`  
**JIRA:** [Issue #3 - Configure service discovery and centralized config management](https://github.com/orgs/PetClinic-Project-Team/projects/1/views/2?pane=issue&itemId=184930136&issue=PetClinic-Project-Team%7Cspring-petclinic-microservices%7C3)  
**Owner:** Harini (P4 — Config & Discovery Engineer)  
**Status:** 🟢 Deployed and Verified on EKS  
**Completed:** May 11, 2026

---

## What Is This Work?

This folder contains the Kubernetes manifests to deploy two critical foundation
services for the Spring PetClinic Microservices application on AWS EKS.

These two services are the backbone of the entire application.
Nothing else can start without them.

### 1. Config Server (port 8888)
The Config Server is the **first service that must start**.
It acts as a central configuration manager — every other microservice
fetches its settings from here on startup.

It reads all configuration files from the external GitHub config repository:
https://github.com/spring-petclinic/spring-petclinic-microservices-config

Without Config Server running and healthy, NO other service can start.

### 2. Discovery Server / Eureka (port 8761)
The Discovery Server is the **second service that must start**.
It is a Eureka service registry — every microservice registers itself
here when it starts up. The API Gateway uses Eureka to route traffic
dynamically across multiple service instances.

### Startup Order (Critical)

Config Server  (port 8888)
↓
Discovery Server (port 8761)
↓
All other services (customers, vets, visits, api-gateway, genai, admin)


---

## Files in This Folder
k8s/
├── config-server/
│   ├── README.md            ← this file
│   ├── deployment.yaml      ← K8s Deployment for config-server
│   └── service.yaml         ← K8s ClusterIP Service on port 8888
└── discovery-server/
├── README.md            ← discovery server notes
├── deployment.yaml      ← K8s Deployment for discovery-server
└── service.yaml         ← K8s ClusterIP Service on port 8761

---

## Completed Work ✅

- [x] Created feature branch `feature/issue-3-config-discovery`
- [x] Ran both services locally using `docker compose up config-server discovery-server`
- [x] Verified config-server health locally → `{"status":"UP"}`
- [x] Verified config-server serves configs from GitHub config repo
- [x] Verified Eureka dashboard loads at `http://localhost:8761`
- [x] Written K8s Deployment + Service manifests for config-server
- [x] Written K8s Deployment + Service manifests for discovery-server
- [x] discovery-server uses initContainer to wait for config-server health
- [x] Deployed config-server to EKS namespace `spring-petclinic` → `1/1 Running`
- [x] Deployed discovery-server to EKS namespace `spring-petclinic` → `1/1 Running`
- [x] Created ClusterIP services for both
- [x] All smoke tests passed on EKS ✅

---

## Deployment Status on EKS

| Resource | Name | Status | Port |
|---|---|---|---|
| Pod | config-server | 1/1 Running ✅ | 8888 |
| Pod | discovery-server | 1/1 Running ✅ | 8761 |
| Service | config-server | ClusterIP ✅ | 8888/TCP |
| Service | discovery-server | ClusterIP ✅ | 8761/TCP |

**Cluster:** petclinic-cluster  
**Region:** us-east-1  
**Namespace:** spring-petclinic  

---

## Smoke Test Results ✅

### Test 1 — Config Server Health (Local)
```bash
curl http://localhost:8888/actuator/health
```
**Result:** ✅ PASSED
- Config server UP and serving configs
- Successfully reading from GitHub config repo
- Version: 323993ce2519c6d02df63e08bf4458d123d3b611
- Eureka settings confirmed
- Prometheus metrics enabled

### Test 2 — Config Server Health (EKS via port-forward)
```bash
kubectl port-forward -n spring-petclinic svc/config-server 8888:8888
curl http://localhost:8888/actuator/health
```
**Result:** ✅ PASSED
- Config server serving configs from GitHub config repo on EKS
- All microservice configs available
- Same config version as local test confirmed

### Test 3 — Discovery Server Health (Local)
```bash
curl http://localhost:8761/actuator/health
```
**Result:** ✅ PASSED
- `{"status":"UP"}`
- Eureka server running correctly

### Test 4 — Eureka Dashboard (Local)
Open browser: http://localhost:8761
**Result:** ✅ PASSED
- Eureka dashboard loads correctly
- System Status: UP
- Ready to accept service registrations

### Test 5 — Eureka Dashboard (EKS via port-forward)
```bash
kubectl port-forward -n spring-petclinic svc/discovery-server 8761:8761
# Open browser: http://localhost:8761
```
**Result:** ✅ PASSED
- Eureka dashboard loads on EKS
- System Status: UP
- Uptime confirmed

### Test 6 — InitContainer Dependency Check
**Result:** ✅ PASSED
- discovery-server initContainer correctly waited for config-server
- Logs confirmed: "Waiting for config-server..." → "Config server is ready!"
- discovery-server only started AFTER config-server was healthy

### Test 7 — Pod and Service Verification
```bash
kubectl get pods,svc -n spring-petclinic
```
**Result:** ✅ PASSED
pod/config-server     1/1   Running   0   restarts
pod/discovery-server  1/1   Running   0   restarts
svc/config-server     ClusterIP   8888/TCP
svc/discovery-server  ClusterIP   8761/TCP

---

## Pending (Depends on Other Team Members) ⏳

- [ ] Connect all microservices to config server
      → P5 (customers + vets), P6 (visits + api-gateway) to deploy their services
- [ ] Test service discovery between services
      → Verify all services appear in Eureka dashboard after P5, P6 deploy
- [ ] All services register with Eureka
      → Will be verified once full team deployment is complete

---

## What Other Services Need

When other team members deploy their services,
they must include these env vars in their K8s deployments:

```yaml
env:
  - name: SPRING_PROFILES_ACTIVE
    value: "docker"
  - name: CONFIG_SERVER_URL
    value: "http://config-server:8888"
```

The service names `config-server` and `discovery-server` are the
Kubernetes service names — they resolve automatically inside the cluster.

---

## How to Connect and Verify (For Team Members)

### Step 1 — Authenticate to AWS and Connect to EKS
```bash
# Configure AWS CLI with your credentials from P2
aws configure

# Assume EKS Developer Role (get role ARN from P2)
aws sts assume-role \
  --role-arn <ROLE_ARN_FROM_P2> \
  --role-session-name dev-session

# Export the temporary credentials from the output above
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."

# Connect to EKS cluster
aws eks update-kubeconfig --name petclinic-cluster --region us-east-1
```

### Step 2 — Verify Pods and Services
```bash
kubectl get pods,svc -n spring-petclinic
```

### Step 3 — Test Config Server
```bash
kubectl port-forward -n spring-petclinic svc/config-server 8888:8888

# In second terminal
curl http://localhost:8888/actuator/health
```

### Step 4 — Open Eureka Dashboard
```bash
kubectl port-forward -n spring-petclinic svc/discovery-server 8761:8761
# Open browser: http://localhost:8761
```

---

## Useful Debug Commands

```bash
# Check all pods and services
kubectl get pods,svc -n spring-petclinic

# Check config-server logs
kubectl logs -n spring-petclinic -l app=config-server --tail=20

# Check discovery-server logs
kubectl logs -n spring-petclinic -l app=discovery-server --tail=20

# Describe pod if not starting
kubectl describe pod -n spring-petclinic -l app=config-server
kubectl describe pod -n spring-petclinic -l app=discovery-server

# Check cluster events for errors
kubectl get events -n spring-petclinic --sort-by='.lastTimestamp'

# Restart a deployment if needed
kubectl rollout restart deployment/config-server -n spring-petclinic
kubectl rollout restart deployment/discovery-server -n spring-petclinic
```

---

## JIRA Acceptance Criteria

| Criteria | Status |
|---|---|
| Config server serves correct configs per environment | ✅ Verified on EKS |
| Discovery server (Eureka) running | ✅ Verified on EKS |
| All services register with Eureka | ⏳ Waiting for other services |
| Services can discover each other dynamically | ⏳ Waiting for other services |
