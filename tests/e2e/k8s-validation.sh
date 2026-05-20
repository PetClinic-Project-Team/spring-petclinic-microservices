#!/usr/bin/env bash
# K8s Infrastructure Validation — TC-INF-001 through TC-INF-007
# Usage: ./tests/e2e/k8s-validation.sh

set -o pipefail

NAMESPACE="spring-petclinic"
PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS++)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL++)); }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

echo "============================================================"
echo " K8s Infrastructure Validation"
echo " Namespace: $NAMESPACE"
echo " $(date)"
echo "============================================================"

# TC-INF-001: EKS Nodes Ready
info "TC-INF-001: Checking EKS nodes..."
NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready" | wc -l | tr -d ' ')
if [ "$NOT_READY" -eq 0 ]; then
  NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
  pass "TC-INF-001: All $NODE_COUNT EKS node(s) are Ready"
else
  fail "TC-INF-001: $NOT_READY node(s) are NOT Ready"
  kubectl get nodes
fi

# TC-INF-002: Namespace exists
info "TC-INF-002: Checking namespace..."
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
  pass "TC-INF-002: Namespace '$NAMESPACE' exists and is Active"
else
  fail "TC-INF-002: Namespace '$NAMESPACE' does not exist"
fi

# TC-INF-003 & TC-INF-004: All pods Running, no CrashLoopBackOff
info "TC-INF-003/004: Checking pod states..."
TOTAL_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
RUNNING_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep "Running" | wc -l | tr -d ' ')
CRASH_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep "CrashLoopBackOff" | wc -l | tr -d ' ')
ERROR_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep "Error" | wc -l | tr -d ' ')
PENDING_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep "Pending" | wc -l | tr -d ' ')

if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
  pass "TC-INF-003: All $TOTAL_PODS pods are in Running state"
else
  fail "TC-INF-003: Only $RUNNING_PODS/$TOTAL_PODS pods are Running"
  kubectl get pods -n "$NAMESPACE"
fi

if [ "$CRASH_PODS" -eq 0 ] && [ "$ERROR_PODS" -eq 0 ] && [ "$PENDING_PODS" -eq 0 ]; then
  pass "TC-INF-004: No pods in CrashLoopBackOff, Error, or Pending state"
else
  fail "TC-INF-004: Problem pods — CrashLoop:$CRASH_PODS Error:$ERROR_PODS Pending:$PENDING_PODS"
fi

# TC-INF-005: Expected services exist
info "TC-INF-005: Checking expected services..."
EXPECTED_SERVICES=(config-server discovery-server api-gateway customers-service vets-service visits-service)
ALL_SVC_OK=true
for SVC in "${EXPECTED_SERVICES[@]}"; do
  if kubectl get svc "$SVC" -n "$NAMESPACE" &>/dev/null; then
    :
  else
    fail "TC-INF-005: Service '$SVC' not found in namespace $NAMESPACE"
    ALL_SVC_OK=false
  fi
done
if $ALL_SVC_OK; then
  pass "TC-INF-005: All expected services exist in namespace $NAMESPACE"
fi

# TC-INF-006: API Gateway has LoadBalancer IP
info "TC-INF-006: Checking API Gateway LoadBalancer..."
GW_HOSTNAME=$(kubectl get svc api-gateway -n "$NAMESPACE" \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
GW_IP=$(kubectl get svc api-gateway -n "$NAMESPACE" \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -n "$GW_HOSTNAME" ] || [ -n "$GW_IP" ]; then
  ENDPOINT="${GW_HOSTNAME:-$GW_IP}"
  pass "TC-INF-006: API Gateway LoadBalancer endpoint: $ENDPOINT"
  echo "  export GW_IP=$ENDPOINT"
else
  fail "TC-INF-006: API Gateway has no external LoadBalancer IP/hostname assigned yet"
fi

# TC-INF-007: Check for OOMKilled events
info "TC-INF-007: Checking for OOMKilled events..."
OOM_COUNT=$(kubectl get events -n "$NAMESPACE" 2>/dev/null | grep -i "OOMKill" | wc -l | tr -d ' ')
if [ "$OOM_COUNT" -eq 0 ]; then
  pass "TC-INF-007: No OOMKilled events in namespace $NAMESPACE"
else
  fail "TC-INF-007: $OOM_COUNT OOMKilled event(s) found — check resource limits"
fi

# TC-DB-003: Database secret exists
info "TC-DB-003: Checking database credentials secret..."
if kubectl get secret petclinic-db-secret -n "$NAMESPACE" &>/dev/null; then
  pass "TC-DB-003: Secret 'petclinic-db-secret' exists"
else
  fail "TC-DB-003: Secret 'petclinic-db-secret' not found — DB connections will fail"
fi

echo ""
echo "============================================================"
echo " Infrastructure Validation Complete"
echo " PASSED: $PASS | FAILED: $FAIL"
echo "============================================================"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
