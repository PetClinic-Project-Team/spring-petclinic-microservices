# Spring PetClinic Microservices — Test Cases

**Document Version:** 1.0  
**Author:** P9 — QA & Demo Lead  
**Date:** 2026-05-13

> **Priority Legend:** P0 = Critical (blocking) | P1 = High | P2 = Medium | P3 = Low

---

## Module 1: Infrastructure Validation

### TC-INF-001 — EKS Nodes Ready
- **Priority:** P0
- **Prerequisite:** `aws eks update-kubeconfig --name petclinic-cluster --region us-east-1`
- **Steps:**
  1. Run `kubectl get nodes`
- **Expected Result:** All nodes show `STATUS = Ready`
- **Automated:** `k8s-validation.sh`

### TC-INF-002 — Namespace Exists
- **Priority:** P0
- **Steps:**
  1. Run `kubectl get namespace spring-petclinic`
- **Expected Result:** Namespace `spring-petclinic` in `Active` state
- **Automated:** `k8s-validation.sh`

### TC-INF-003 — All Pods Running
- **Priority:** P0
- **Steps:**
  1. Run `kubectl get pods -n spring-petclinic`
- **Expected Result:** All pods show `STATUS = Running`, `RESTARTS = 0` (or low)
- **Automated:** `k8s-validation.sh`

### TC-INF-004 — No CrashLoopBackOff Pods
- **Priority:** P0
- **Steps:**
  1. Run `kubectl get pods -n spring-petclinic | grep -v Running | grep -v Completed`
- **Expected Result:** No pods in `CrashLoopBackOff`, `Error`, or `Pending` state
- **Automated:** `k8s-validation.sh`

### TC-INF-005 — All Services Have Endpoints
- **Priority:** P1
- **Steps:**
  1. Run `kubectl get svc -n spring-petclinic`
- **Expected Result:** All expected services listed with correct port mappings
- **Automated:** `k8s-validation.sh`

### TC-INF-006 — API Gateway LoadBalancer IP Assigned
- **Priority:** P0
- **Steps:**
  1. Run `kubectl get svc api-gateway -n spring-petclinic -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'`
- **Expected Result:** Non-empty hostname returned (AWS ELB DNS name)
- **Automated:** `k8s-validation.sh`

### TC-INF-007 — Resource Requests/Limits Not Exceeded
- **Priority:** P2
- **Steps:**
  1. Run `kubectl top pods -n spring-petclinic`
- **Expected Result:** No pod exceeds its memory limit (no OOMKilled events)
- **Manual:** Check via `kubectl describe pod` for OOMKilled events

---

## Module 2: Config & Discovery Server

### TC-CFG-001 — Config Server Health Endpoint
- **Priority:** P0
- **Steps:**
  1. `kubectl port-forward -n spring-petclinic svc/config-server 8888:8888`
  2. `curl -s http://localhost:8888/actuator/health | jq .status`
- **Expected Result:** `"UP"`
- **Automated:** `health-check.sh`

### TC-CFG-002 — Config Server Serving Configuration
- **Priority:** P1
- **Steps:**
  1. Port-forward config-server to 8888
  2. `curl -s http://localhost:8888/customers-service/docker`
- **Expected Result:** JSON response containing datasource and Spring config properties
- **Automated:** `health-check.sh`

### TC-DIS-001 — Discovery Server Health Endpoint
- **Priority:** P0
- **Steps:**
  1. `kubectl port-forward -n spring-petclinic svc/discovery-server 8761:8761`
  2. `curl -s http://localhost:8761/actuator/health | jq .status`
- **Expected Result:** `"UP"`
- **Automated:** `health-check.sh`

### TC-DIS-002 — All Microservices Registered in Eureka
- **Priority:** P0
- **Steps:**
  1. Port-forward discovery-server to 8761
  2. `curl -s -H "Accept: application/json" http://localhost:8761/eureka/apps | jq '.applications.application[].name'`
- **Expected Result:** Output includes `CUSTOMERS-SERVICE`, `VETS-SERVICE`, `VISITS-SERVICE`, `API-GATEWAY`
- **Automated:** `health-check.sh`

### TC-DIS-003 — Eureka Dashboard Accessible
- **Priority:** P2
- **Steps:**
  1. Port-forward discovery-server to 8761
  2. Open browser: `http://localhost:8761`
- **Expected Result:** Eureka web UI loads, shows registered services
- **Manual:** Screenshot required for presentation

---

## Module 3: API Gateway

### TC-GW-001 — Gateway Homepage Returns HTTP 200
- **Priority:** P0
- **Steps:**
  1. Get LoadBalancer IP: `GW_IP=$(kubectl get svc api-gateway -n spring-petclinic -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')`
  2. `curl -s -o /dev/null -w "%{http_code}" http://$GW_IP`
- **Expected Result:** `200`
- **Automated:** `api-tests.sh`

### TC-GW-002 — Gateway Routes Customer API Correctly
- **Priority:** P0
- **Steps:**
  1. `curl -s http://$GW_IP/api/customer/owners`
- **Expected Result:** HTTP 200, JSON array of owner objects
- **Automated:** `api-tests.sh`

### TC-GW-003 — Gateway Routes Vets API Correctly
- **Priority:** P0
- **Steps:**
  1. `curl -s http://$GW_IP/api/vet/vets`
- **Expected Result:** HTTP 200, JSON array of vet objects
- **Automated:** `api-tests.sh`

### TC-GW-004 — Gateway Routes Visits API Correctly
- **Priority:** P1
- **Steps:**
  1. `curl -s http://$GW_IP/api/visit/owners/1/pets/1/visits`
- **Expected Result:** HTTP 200, JSON array (may be empty, but not 404/500)
- **Automated:** `api-tests.sh`

---

## Module 4: Customers Service

### TC-CST-001 — List All Owners
- **Priority:** P0
- **Steps:**
  1. `curl -s http://$GW_IP/api/customer/owners`
- **Expected Result:** HTTP 200, non-empty JSON array with fields: `id`, `firstName`, `lastName`, `address`, `city`, `telephone`
- **Automated:** `api-tests.sh`

### TC-CST-002 — Get Owner by ID
- **Priority:** P1
- **Steps:**
  1. `curl -s http://$GW_IP/api/customer/owners/1`
- **Expected Result:** HTTP 200, single owner JSON object with `id: 1`
- **Automated:** `api-tests.sh`

### TC-CST-003 — Create New Owner
- **Priority:** P0
- **Steps:**
  1. POST request with owner JSON payload
  2. `curl -s -X POST http://$GW_IP/api/customer/owners -H "Content-Type: application/json" -d '{"firstName":"Test","lastName":"User","address":"123 Test St","city":"TestCity","telephone":"1234567890"}'`
- **Expected Result:** HTTP 201 or 200, response contains created owner with `id` field
- **Automated:** `api-tests.sh`

### TC-CST-004 — Get Owner Not Found (Negative)
- **Priority:** P2
- **Steps:**
  1. `curl -s -o /dev/null -w "%{http_code}" http://$GW_IP/api/customer/owners/99999`
- **Expected Result:** HTTP 404
- **Automated:** `api-tests.sh`

### TC-CST-005 — List Pets for Owner
- **Priority:** P1
- **Steps:**
  1. `curl -s http://$GW_IP/api/customer/owners/1`
  2. Verify `pets` array is present in response
- **Expected Result:** HTTP 200, owner JSON contains `pets` array
- **Automated:** `api-tests.sh`

### TC-CST-006 — List Pet Types
- **Priority:** P1
- **Steps:**
  1. `curl -s http://$GW_IP/api/customer/petTypes`
- **Expected Result:** HTTP 200, JSON array containing pet types (cat, dog, etc.)
- **Automated:** `api-tests.sh`

---

## Module 5: Vets Service

### TC-VET-001 — List All Vets
- **Priority:** P0
- **Steps:**
  1. `curl -s http://$GW_IP/api/vet/vets`
- **Expected Result:** HTTP 200, JSON array with vet objects containing `id`, `firstName`, `lastName`, `specialties`
- **Automated:** `api-tests.sh`

### TC-VET-002 — Vets Data Contains Specialties
- **Priority:** P1
- **Steps:**
  1. `curl -s http://$GW_IP/api/vet/vets | jq '.[0].specialties'`
- **Expected Result:** Array field present (may be empty for generalist vets, but field exists)
- **Automated:** `api-tests.sh`

### TC-VET-003 — Vets Service Direct Health Check
- **Priority:** P1
- **Steps:**
  1. `kubectl port-forward -n spring-petclinic svc/vets-service 8083:8083`
  2. `curl -s http://localhost:8083/actuator/health | jq .status`
- **Expected Result:** `"UP"`
- **Automated:** `health-check.sh`

---

## Module 6: Visits Service

### TC-VST-001 — List Visits for a Pet
- **Priority:** P0
- **Steps:**
  1. `curl -s http://$GW_IP/api/visit/owners/1/pets/1/visits`
- **Expected Result:** HTTP 200, JSON array (may be empty initially)
- **Automated:** `api-tests.sh`

### TC-VST-002 — Create a New Visit
- **Priority:** P0
- **Steps:**
  1. POST to visits endpoint:
     ```
     curl -s -X POST http://$GW_IP/api/visit/owners/1/pets/1/visits \
       -H "Content-Type: application/json" \
       -d '{"date":"2026-05-14","description":"Annual check-up"}'
     ```
- **Expected Result:** HTTP 201 or 200, visit created with `id` field in response
- **Automated:** `api-tests.sh`

### TC-VST-003 — Verify Visit Persists After Creation
- **Priority:** P1
- **Steps:**
  1. Create a visit (TC-VST-002)
  2. `curl -s http://$GW_IP/api/visit/owners/1/pets/1/visits`
  3. Verify the new visit appears in the list
- **Expected Result:** Visit count increases by 1 after creation
- **Manual:** Verify via browser UI

### TC-VST-004 — Visits Service Direct Health Check
- **Priority:** P1
- **Steps:**
  1. `kubectl port-forward -n spring-petclinic svc/visits-service 8082:8082`
  2. `curl -s http://localhost:8082/actuator/health | jq .status`
- **Expected Result:** `"UP"`
- **Automated:** `health-check.sh`

---

## Module 7: Database Validation

### TC-DB-001 — Customers Database Connectivity
- **Priority:** P0
- **Steps:**
  1. `kubectl run mysql-test --rm -it --image=mysql:8 -n spring-petclinic -- mysql -h customers-db-mysql -u petclinic -ppetclinic petclinic -e "SELECT COUNT(*) FROM owners;"`
- **Expected Result:** Returns count ≥ 1 (seed data loaded)
- **Manual**

### TC-DB-002 — Vets Database Has Seed Data
- **Priority:** P1
- **Steps:**
  1. `kubectl run mysql-test2 --rm -it --image=mysql:8 -n spring-petclinic -- mysql -h vets-db-mysql -u petclinic -ppetclinic petclinic -e "SELECT COUNT(*) FROM vets;"`
- **Expected Result:** Returns count ≥ 1
- **Manual**

### TC-DB-003 — Database Credentials Secret Exists
- **Priority:** P0
- **Steps:**
  1. `kubectl get secret petclinic-db-secret -n spring-petclinic`
- **Expected Result:** Secret exists with type `Opaque`
- **Automated:** `k8s-validation.sh`

---

## Module 8: Observability Stack

### TC-OBS-001 — Prometheus UI Accessible
- **Priority:** P1
- **Steps:**
  1. `kubectl port-forward -n spring-petclinic svc/prometheus-server 9090:80`
  2. `curl -s -o /dev/null -w "%{http_code}" http://localhost:9090`
- **Expected Result:** HTTP 200
- **Automated:** `monitoring-check.sh`

### TC-OBS-002 — Prometheus Scraping All Services
- **Priority:** P1
- **Steps:**
  1. Port-forward Prometheus to 9090
  2. `curl -s "http://localhost:9090/api/v1/targets" | jq '.data.activeTargets[] | select(.health=="up") | .labels.job'`
- **Expected Result:** Output includes targets for all backend services
- **Automated:** `monitoring-check.sh`

### TC-OBS-003 — Grafana UI Accessible
- **Priority:** P1
- **Steps:**
  1. Get Grafana IP: `kubectl get svc grafana -n spring-petclinic`
  2. Open `http://GRAFANA_IP` in browser
- **Expected Result:** Grafana login page loads
- **Automated:** `monitoring-check.sh`

### TC-OBS-004 — Grafana Prometheus Data Source Connected
- **Priority:** P1
- **Steps:**
  1. Log in to Grafana (admin / petclinic123)
  2. Go to Configuration → Data Sources → Prometheus → Test
- **Expected Result:** "Data source is working" message
- **Manual**

### TC-OBS-005 — Zipkin Receives Traces
- **Priority:** P2
- **Steps:**
  1. Get Zipkin IP: `kubectl get svc zipkin -n spring-petclinic`
  2. Open `http://ZIPKIN_IP:9411` in browser
  3. Make an API call: `curl http://$GW_IP/api/customer/owners`
  4. Click "Run Query" in Zipkin
- **Expected Result:** At least one trace appears with multiple spans
- **Manual**

### TC-OBS-006 — Grafana JVM Dashboard Shows Data
- **Priority:** P2
- **Steps:**
  1. Log in to Grafana
  2. Open JVM dashboard (ID: 4701 or custom PetClinic dashboard)
  3. Set time range to last 15 minutes
- **Expected Result:** JVM heap, CPU, thread count metrics displayed with data
- **Manual**

---

## Module 9: End-to-End User Journey

### TC-E2E-001 — Complete Owner Registration Flow
- **Priority:** P0
- **Steps:**
  1. Open `http://$GW_IP` in browser
  2. Click "Find Owners"
  3. Click "Add Owner"
  4. Fill: First Name=`Demo`, Last Name=`User`, Address=`1 AWS St`, City=`Cloud City`, Phone=`5551234567`
  5. Submit form
  6. Verify owner appears in owner list
- **Expected Result:** New owner created and visible in list
- **Manual (Demo)**

### TC-E2E-002 — Pet Registration for Owner
- **Priority:** P0
- **Steps:**
  1. Navigate to the owner created in TC-E2E-001
  2. Click "Add New Pet"
  3. Fill: Name=`CloudBuddy`, Birth Date=`2024-01-01`, Type=`dog`
  4. Submit
  5. Verify pet appears under the owner
- **Expected Result:** Pet created and linked to owner
- **Manual (Demo)**

### TC-E2E-003 — Schedule a Vet Visit
- **Priority:** P0
- **Steps:**
  1. Navigate to the pet created in TC-E2E-002
  2. Click "Add Visit"
  3. Fill: Date=`2026-05-14`, Description=`Annual Wellness Check`
  4. Submit
  5. Verify visit appears in visit history
- **Expected Result:** Visit scheduled and shows in pet history
- **Manual (Demo)**

### TC-E2E-004 — View Vets List from UI
- **Priority:** P1
- **Steps:**
  1. Open `http://$GW_IP` in browser
  2. Click "Find Vets"
- **Expected Result:** List of vets rendered with name and specialties
- **Manual (Demo)**

---

## Module 10: GenAI Chatbot Service

### TC-GENAI-001 — GenAI Service Pod Running
- **Priority:** P1
- **Steps:**
  1. `kubectl get pods -n spring-petclinic | grep genai`
- **Expected Result:** `genai-service` pod shows `STATUS = Running`, `READY = 1/1`
- **Automated:** `k8s-validation.sh`

### TC-GENAI-002 — GenAI Service Health Endpoint
- **Priority:** P1
- **Steps:**
  1. `kubectl port-forward -n spring-petclinic svc/genai-service 8084:8084`
  2. `curl -s http://localhost:8084/actuator/health | jq .status`
- **Expected Result:** `"UP"`
- **Automated:** `health-check.sh`

### TC-GENAI-003 — Chatbot Responds to Question via API Gateway
- **Priority:** P1
- **Steps:**
  1. Get gateway URL
  2. `curl -s -X POST http://$GW_IP/api/genai/chatclient -H "Content-Type: application/json" -d '{"message":"Which vets specialize in dentistry?"}' --max-time 60`
- **Expected Result:** HTTP 200, response body contains a natural language answer (not a JSON error)
- **Automated:** `api-tests.sh`

### TC-GENAI-004 — Chatbot Returns Live Data from Vets Service
- **Priority:** P1
- **Steps:**
  1. `curl -s -X POST http://$GW_IP/api/genai/chatclient -H "Content-Type: application/json" -d '{"message":"List all veterinarians"}' --max-time 60`
- **Expected Result:** Response mentions at least one vet name from the live vets database (e.g., "Linda Douglas", "Helen Leary")
- **Manual**

### TC-GENAI-005 — Kubernetes Self-Healing (Chaos Test)
- **Priority:** P2
- **Steps:**
  1. `kubectl get pods -n spring-petclinic -l app=api-gateway`
  2. `kubectl delete pod -n spring-petclinic -l app=api-gateway --wait=false`
  3. `kubectl get pods -n spring-petclinic -l app=api-gateway -w`
- **Expected Result:** Deleted pod terminates, Kubernetes immediately schedules a replacement. New pod reaches `Running` state within 60 seconds
- **Automated:** `tests/e2e/chaos-demo.sh`

---

## Test Summary Tracker

| Module              | Total | P0 | P1 | P2 | P3 |
|---------------------|-------|----|----|----|----|
| Infrastructure      | 7     | 5  | 1  | 1  | 0  |
| Config & Discovery  | 5     | 3  | 1  | 1  | 0  |
| API Gateway         | 4     | 3  | 1  | 0  | 0  |
| Customers Service   | 6     | 2  | 2  | 1  | 0  |
| Vets Service        | 3     | 1  | 2  | 0  | 0  |
| Visits Service      | 4     | 2  | 2  | 0  | 0  |
| Database            | 3     | 2  | 1  | 0  | 0  |
| Observability       | 6     | 0  | 3  | 2  | 0  |
| End-to-End Journey  | 4     | 3  | 1  | 0  | 0  |
| **GenAI Chatbot**   | **5** | **0**|**4**|**1**|**0**|
| **Total**           | **47**|**21**|**18**|**6**|**0**|
