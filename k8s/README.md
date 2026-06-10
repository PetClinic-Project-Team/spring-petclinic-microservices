# Observability & Monitoring with Prometheus and Grafana

This guide walks you through the **complete setup** of a Prometheus‑Grafana observability stack for the Spring Petclinic micro‑services running on an Amazon EKS cluster.  It assumes you have already deployed the services (see the main deployment guide) and that you have the following tools installed and configured:

- **kubectl** – connectivity to your EKS cluster (`kubectl get nodes` should work)
- **helm 3** – for installing the Prometheus operator and Grafana charts
- **aws cli**, **eksctl** – only needed if you still need to create the cluster/ECR repository (not covered here)

The steps are broken into small, easy‑to‑follow commands you can copy‑paste.
---
## 1️⃣ Create a namespace for monitoring
```bash
kubectl create namespace monitoring
```
All monitoring resources will be placed in this namespace, keeping them separate from the `petclinic` application namespace.
---
## 2️⃣ Install the Prometheus Operator (kube‑prometheus‑stack)
The **kube‑prometheus‑stack** Helm chart bundles Prometheus, Alertmanager, node‑exporter and related CRDs.
```bash
# Add the Helm repo (if you haven't already)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create a minimal values file so ServiceMonitors are enabled
cat > monitoring/prometheus-values.yaml <<'EOF'
prometheus:
  serviceMonitorSelectorNilUsesHelmValues: false
  serviceMonitorSelector:
    matchLabels:
      prometheus: enabled
grafana:
  enabled: false   # we will install Grafana separately
EOF

# Install/upgrade the stack
helm upgrade --install prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f monitoring/prometheus-values.yaml
```
The command creates:
- `prometheus-stack-prometheus` (Prometheus server)
- `prometheus-stack-alertmanager`
- `prometheus-stack-operator`
- CRDs for `ServiceMonitor` and `PrometheusRule`
---
## 3️⃣ Label the Petclinic deployments so Prometheus can discover them
Each Spring Boot micro‑service already exposes a Prometheus endpoint at
`http://<service>:<port>/actuator/prometheus`.  We simply add a label `prometheus=enabled` to the deployments.
```bash
for svc in config-server discovery-server api-gateway customers-service visits-service vets-service admin-server genai-service; do
  kubectl -n petclinic label deployment "$svc" prometheus=enabled --overwrite
 done
```
---
## 4️⃣ Create **ServiceMonitors** for each service
A `ServiceMonitor` tells the Prometheus Operator which `Service` to scrape.
Create a single file `monitoring/petclinic-servicemonitors.yaml` with one block per service.  Only the `metadata.name` and the `matchLabels.app` change.
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: petclinic-config-server
  labels:
    prometheus: enabled
spec:
  selector:
    matchLabels:
      app: config-server
  namespaceSelector:
    matchNames:
      - petclinic
  endpoints:
    - port: http
      path: /actuator/prometheus
      interval: 15s
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: petclinic-discovery-server
  labels:
    prometheus: enabled
spec:
  selector:
    matchLabels:
      app: discovery-server
  namespaceSelector:
    matchNames:
      - petclinic
  endpoints:
    - port: http
      path: /actuator/prometheus
      interval: 15s
---
# Repeat the block for the remaining services: api-gateway, customers-service, visits-service,
# vets-service, admin-server, genai-service – only change the `metadata.name` and the `matchLabels.app` values.
```
Apply the file:
```bash
kubectl apply -f monitoring/petclinic-servicemonitors.yaml
```
Prometheus will now start scraping `http://<service>:<port>/actuator/prometheus` every 15 seconds.
---
## 5️⃣ Deploy Grafana (stand‑alone, easier to customize)
Grafana will read data from the Prometheus instance we just installed.
```bash
# Add the Grafana repo (if not already added)
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

cat > monitoring/grafana-values.yaml <<'EOF'
adminUser: admin
adminPassword: admin123   # **CHANGE THIS AFTER FIRST LOGIN**
service:
  type: LoadBalancer   # Exposes Grafana publicly; change to ClusterIP if you prefer an Ingress
persistence:
  enabled: true
  size: 2Gi
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
        isDefault: true
        editable: true
EOF

helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  -f monitoring/grafana-values.yaml
```
The chart creates a Service `grafana` of type `LoadBalancer`.  Retrieve the external IP:
```bash
kubectl -n monitoring get svc grafana
```
Open the IP in a browser (`http://<EXTERNAL_IP>`) and log in with **admin / admin123**.
---
## 6️⃣ Verify the stack
### 6.1 Prometheus UI
```bash
# Port‑forward locally (optional, for quick testing)
kubectl -n monitoring port-forward svc/prometheus-stack-prometheus 9090:9090 &
```
Open <http://localhost:9090> and run a query such as:
```
up{namespace="petclinic"}
```
You should see a series of `1`s – one for each micro‑service that is up.

### 6.2 Grafana dashboard
1. In Grafana, go to **Configuration → Data Sources** – you will see the Prometheus datasource already created.
2. Click **Create → Import** and import the community dashboard **#4701 – Spring Boot Micrometer** (search for *4701* on Grafana.com).  This dashboard visualizes JVM, HTTP request, and custom Micrometer metrics automatically.
3. After import, you should see live graphs for:
   - `jvm_memory_used_bytes`
   - `http_server_requests_seconds_count`
   - any custom `petclinic.*` metrics you defined.
---
## 7️⃣ (Optional) Simple alerting
If you want to be notified when a service goes down, add a `PrometheusRule`:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: petclinic-down
  labels:
    prometheus: enabled
spec:
  groups:
    - name: petclinic.rules
      rules:
        - alert: ServiceDown
          expr: up{namespace="petclinic"} == 0
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "{{ $labels.app }} is down"
            description: "{{ $labels.app }} has been down for more than 2 minutes."
```
Apply it:
```bash
kubectl apply -f monitoring/petclinic-alert-rule.yaml
```
Alertmanager (installed with the stack) will fire the alert.  You can configure Alertmanager to forward alerts to Slack, email, or Amazon SNS – see the `alertmanager.yaml` ConfigMap in the Helm chart for details.
---
## 8️⃣ TL;DR – copy‑paste commands
```bash
# 1. Namespace
kubectl create namespace monitoring

# 2. Prometheus operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
cat > monitoring/prometheus-values.yaml <<'EOF'
prometheus:
  serviceMonitorSelectorNilUsesHelmValues: false
  serviceMonitorSelector:
    matchLabels:
      prometheus: enabled
grafana:
  enabled: false
EOF
helm upgrade --install prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring -f monitoring/prometheus-values.yaml

# 3. Label services (run from repo root)
for svc in config-server discovery-server api-gateway customers-service visits-service vets-service admin-server genai-service; do
  kubectl -n petclinic label deployment $svc prometheus=enabled --overwrite
done

# 4. ServiceMonitors (apply the YAML prepared above)
kubectl apply -f monitoring/petclinic-servicemonitors.yaml

# 5. Grafana
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
cat > monitoring/grafana-values.yaml <<'EOF'
adminUser: admin
adminPassword: admin123
service:
  type: LoadBalancer
persistence:
  enabled: true
  size: 2Gi
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
        isDefault: true
        editable: true
EOF
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring -f monitoring/grafana-values.yaml

# 6. Verify
kubectl -n monitoring get svc grafana   # find external IP
kubectl -n monitoring port-forward svc/prometheus-stack-prometheus 9090:9090 &
# then open http://localhost:9090 and run up{namespace="petclinic"}
```
---
## 📚 What you have now
* All nine Spring Petclinic micro‑services expose **/actuator/prometheus** and are scraped by Prometheus.
* **Grafana** provides a ready‑made dashboard (or you can import the Micrometer one) that visualizes JVM, HTTP, and custom business metrics.
* A simple **alert** fires when any service becomes unavailable.

You can now monitor performance, spot bottlenecks, and set up alerts for production usage. Feel free to extend the dashboards, add more Prometheus rules, or integrate Alertmanager with your incident‑response tools.
