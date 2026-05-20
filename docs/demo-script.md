# Spring PetClinic Microservices — Live Demo Script

**Author:** P9 — QA & Demo Lead  
**Date:** 2026-05-13  
**Demo Duration:** ~7 minutes  

---

## Pre-Demo Checklist (30 min before presentation)

Run these commands to ensure everything is ready:

```bash
# 1. Verify cluster is up
kubectl get nodes

# 2. Verify all pods are running
kubectl get pods -n spring-petclinic

# 3. Get the app URL
export GW_IP=$(kubectl get svc api-gateway -n spring-petclinic \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "App URL: http://$GW_IP"

# 4. Get Grafana URL
export GRAFANA_IP=$(kubectl get svc grafana -n spring-petclinic \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Grafana URL: http://$GRAFANA_IP"

# 5. Get Zipkin URL
export ZIPKIN_IP=$(kubectl get svc zipkin -n spring-petclinic \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Zipkin URL: http://$ZIPKIN_IP:9411"

# 6. Start Eureka port-forward in background
kubectl port-forward -n spring-petclinic svc/discovery-server 8761:8761 &
echo "Eureka: http://localhost:8761"
```

**Open these browser tabs before starting:**
| Tab | URL | Purpose |
|-----|-----|---------|
| Tab 1 | `http://k8s-springpe-petclini-f8fb5cb536-495336108.us-east-1.elb.amazonaws.com` | Live PetClinic App (port 80) |
| Tab 2 | `http://localhost:8761` | Eureka Service Registry |
| Tab 3 | `http://$GRAFANA_IP` | Grafana Metrics |
| Tab 4 | `http://$ZIPKIN_IP:9411` | Zipkin Distributed Traces |
| Tab 5 | GitHub Actions | CI/CD Pipeline |
| Tab 6 | Terminal | kubectl commands |

---

## Demo Script

---

### [0:00 — 0:30] Opening Statement

> *"Good [morning/afternoon] everyone. I'm the QA and Demo Lead for this project.  
> My responsibility was to create a comprehensive test plan, validate all services  
> end-to-end, and demonstrate that our Spring PetClinic Microservices system  
> running on AWS EKS works exactly as intended.  
> Let me show you the live system."*

---

### [0:30 — 1:00] Step 1 — Show the Live Cluster

**Switch to Terminal.**

```bash
# Show the cluster is running on AWS
kubectl get nodes -o wide
```

> *"We have [X] worker nodes running on AWS EKS. All nodes are in Ready state."*

```bash
# Show all microservices are deployed and running
kubectl get pods -n spring-petclinic
```

> *"Every microservice is running — config-server, discovery-server, api-gateway,  
> customers, vets, visits, and three MySQL databases.  
> No crashes, no restarts. The system is healthy."*

---

### [1:00 — 1:30] Step 2 — Service Discovery (Eureka)

**Switch to Tab 2 (Eureka — http://localhost:8761).**

> *"This is our Eureka service registry. Every microservice automatically  
> registers itself here at startup. You can see all services are registered  
> and their instance IDs. This is what allows our API Gateway to route  
> requests to the correct service without hardcoded URLs."*

---

### [1:30 — 2:30] Step 3 — Live Application Demo

**Switch to Tab 1 (PetClinic App).**

> *"This is our live PetClinic application, accessible via AWS Application  
> Load Balancer. Let me demonstrate the full user journey."*

**Action: Find Owners**
1. Click **"Find Owners"** from the navigation bar
2. Show the existing list of owners (seed data)

> *"We have pre-seeded owners loaded from our MySQL database."*

**Action: Add New Owner**
3. Click **"Add Owner"**
4. Fill in:
   - First Name: `Demo`
   - Last Name: `Petclinic`
   - Address: `100 AWS Boulevard`
   - City: `Cloud City`
   - Telephone: `5551234567`
5. Click **Submit**

> *"Owner created. This was a real write to our MySQL customers database  
> running inside Kubernetes on AWS EKS."*

**Action: Add a Pet**
6. Click on **"Demo Petclinic"** from the owner list
7. Click **"Add New Pet"**
8. Fill in:
   - Name: `CloudBuddy`
   - Birth Date: `2024-01-15`
   - Type: `dog`
9. Click **Submit**

> *"Pet created and linked to the owner."*

**Action: Schedule a Visit**
10. Click **"Add Visit"** next to CloudBuddy
11. Fill in:
    - Date: `2026-05-14`
    - Description: `Annual wellness check-up`
12. Click **Submit**

> *"Visit scheduled. The visits-service processed this request through  
> the API gateway, persisted it to its own MySQL database, and returned  
> the confirmation."*

---

### [2:30 — 3:30] Step 4 — Validate via API (Optional, for technical audience)

**Switch to Terminal.**

```bash
# Show the owner we just created via the REST API
curl -s http://$GW_IP/api/customer/owners | jq '.[] | select(.lastName=="Petclinic")'
```

> *"Here's proof the data is in the database — returned via the REST API  
> that our CI/CD pipeline built, pushed to ECR, and deployed to EKS."*

```bash
# Show vets are loaded
curl -s http://$GW_IP/api/vet/vets | jq 'length'
```

> *"[X] veterinarians loaded from the vets service's separate MySQL database."*

---

### [3:30 — 4:00] Step 5 — Observability: Grafana

**Switch to Tab 3 (Grafana).**

> *"Our P8 team member set up Prometheus and Grafana for real-time observability.  
> This is the JVM metrics dashboard for our microservices."*

1. Open the PetClinic or JVM dashboard
2. Point to:
   - Heap memory graph (show it's stable, no memory leak)
   - HTTP request rate (spike from our demo actions)
   - Active threads

> *"Every API call we just made generated metrics. Prometheus scrapes each  
> microservice's /actuator/prometheus endpoint every 15 seconds."*

---

### [4:00 — 4:30] Step 6 — Distributed Tracing: Zipkin

**Switch to Tab 4 (Zipkin — http://$ZIPKIN_IP:9411).**

1. Click **"Run Query"**
2. Click on one of the traces

> *"Zipkin shows us the complete trace of each request as it travels through  
> the system. This trace shows the request entering the API gateway, being  
> routed to the customers service, hitting the database, and returning.  
> This is crucial for debugging latency issues in production."*

---

### [4:30 — 5:30] Step 7 — AI Chatbot Demo (GenAI Service)

**Switch to Tab 1 (PetClinic App) — chat widget in the bottom-right corner.**

> *"We also integrated a Spring AI-powered chatbot that connects directly  
> to our live microservices data. Let me show you."*

**Action: Ask the chatbot questions using the chat widget**

1. Type: `Which vets specialize in dentistry?`
   > *"The AI answered correctly — Linda Douglas specializes in dentistry and surgery.  
   > This response came from our live vets database."*

2. Type: `List all veterinarians`
   > *"It queries our vets-service in real time and summarises the result  
   > in plain English. This is Spring AI with OpenAI GPT-4o-mini running  
   > inside Kubernetes on AWS EKS."*

---

### [5:30 — 6:30] Step 8 — Chaos Engineering Demo (Kubernetes Self-Healing)

**Switch to Terminal.**

> *"Now I'll show you something impressive — Kubernetes self-healing.  
> I'm going to delete a live running pod right now in front of you."*

```bash
# Show the pod is running
kubectl get pods -n spring-petclinic | grep api-gateway

# Delete it live
kubectl delete pod -n spring-petclinic \
  $(kubectl get pod -n spring-petclinic -l app=api-gateway \
    -o jsonpath='{.items[0].metadata.name}')

# Watch Kubernetes recover automatically
kubectl get pods -n spring-petclinic -l app=api-gateway -w
```

> *"Watch — Kubernetes detected the pod is gone and immediately  
> scheduled a replacement. Within 30 seconds the service is fully  
> restored with zero manual intervention. The app never went down  
> because we run 2 replicas of the API gateway."*

---

### [6:30 — 7:00] Step 9 — Closing

> *"To summarize: in one week, our team deployed a production-grade microservices  
> application on AWS EKS with:  
> ✓ 7 Spring Boot microservices including an AI chatbot  
> ✓ 3 isolated MySQL databases  
> ✓ Automated CI/CD via GitHub Actions + ECR  
> ✓ Full observability with Prometheus, Grafana, and Zipkin  
> ✓ 47 test cases covering all services including genai  
> ✓ Self-healing Kubernetes cluster demonstrated live  
> ✓ Zero critical defects at time of demo  
>  
> The system is live, stable, and ready for questions."*

---

## Contingency Plan (If Something Breaks During Demo)

| Problem | Fallback |
|---------|----------|
| App URL not loading | Switch to port-forward: `kubectl port-forward svc/api-gateway 8080:8080 -n spring-petclinic` |
| Pod in CrashLoop | `kubectl rollout restart deployment/<service> -n spring-petclinic` (takes ~60s) |
| Grafana not loading | Show the pre-captured screenshot in `docs/grafana-custom-metrics-dashboard.png` |
| Eureka not showing all services | Run `kubectl get pods -n spring-petclinic` to show pods are running |
| API call fails | Show `kubectl logs -n spring-petclinic -l app=<service> --tail=20` to demonstrate debugging |
| Chatbot returns 404 | Ask Stevenfavour to confirm the genai route is still in `spring-petclinic-microservices-config/api-gateway.yml`, then restart api-gateway |
| Chatbot says "Chat is currently unavailable" | Check OpenAI credits at platform.openai.com/settings/organization/billing |

---

## Key Commands Reference Card (Print This)

```bash
# Get all URLs
export GW_IP=$(kubectl get svc api-gateway -n spring-petclinic -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
export GRAFANA_IP=$(kubectl get svc grafana -n spring-petclinic -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
export ZIPKIN_IP=$(kubectl get svc zipkin -n spring-petclinic -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Quick health check
kubectl get pods -n spring-petclinic

# API test
curl -s http://$GW_IP/api/customer/owners | jq length
curl -s http://$GW_IP/api/vet/vets | jq length

# Port forwards
kubectl port-forward svc/discovery-server 8761:8761 -n spring-petclinic &
```
