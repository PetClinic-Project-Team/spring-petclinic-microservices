#!/usr/bin/env bash
# Service Health Check — TC-CFG-001, TC-CFG-002, TC-DIS-001, TC-DIS-002, TC-VET-003, TC-VST-004
# Usage: ./tests/e2e/health-check.sh
# Note: Requires kubectl access to the cluster. Uses port-forward for internal services.

set -o pipefail

NAMESPACE="spring-petclinic"
PASS=0
FAIL=0
PF_PIDS=()

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS++)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL++)); }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

cleanup() {
  info "Cleaning up port-forwards..."
  for PID in "${PF_PIDS[@]}"; do
    kill "$PID" 2>/dev/null
  done
}
trap cleanup EXIT

port_forward() {
  local SVC=$1 LOCAL=$2 REMOTE=$3
  kubectl port-forward -n "$NAMESPACE" "svc/$SVC" "$LOCAL:$REMOTE" &>/dev/null &
  PF_PIDS+=($!)
  sleep 4
}

check_health() {
  local TC=$1 URL=$2 DESC=$3
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL" 2>/dev/null)
  HEALTH=$(curl -s --max-time 10 "$URL" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))" 2>/dev/null)
  if [ "$HEALTH" = "UP" ] || [ "$HTTP_STATUS" = "200" ]; then
    pass "$TC: $DESC — status: ${HEALTH:-HTTP $HTTP_STATUS}"
  else
    fail "$TC: $DESC — status: ${HEALTH:-HTTP $HTTP_STATUS} (expected UP/200)"
  fi
}

echo "============================================================"
echo " Service Health Check"
echo " Namespace: $NAMESPACE"
echo " $(date)"
echo "============================================================"

# TC-CFG-001: Config Server health
info "TC-CFG-001: Port-forwarding config-server (8888)..."
port_forward config-server 8888 8888
check_health "TC-CFG-001" "http://localhost:8888/actuator/health" "Config Server health endpoint"

# TC-CFG-002: Config Server serving config for customers-service
info "TC-CFG-002: Checking config server serves customers-service config..."
CFG_RESPONSE=$(curl -s --max-time 10 "http://localhost:8888/customers-service/docker" 2>/dev/null)
if echo "$CFG_RESPONSE" | grep -q "propertySources" 2>/dev/null; then
  pass "TC-CFG-002: Config Server serving configuration for customers-service/docker profile"
else
  fail "TC-CFG-002: Config Server not returning expected config for customers-service/docker"
fi

# TC-DIS-001: Discovery Server health
info "TC-DIS-001: Port-forwarding discovery-server (8761)..."
port_forward discovery-server 8761 8761
HTTP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://localhost:8761" 2>/dev/null)
if [ "$HTTP" = "200" ]; then
  pass "TC-DIS-001: Discovery Server is accessible (HTTP 200)"
else
  fail "TC-DIS-001: Discovery Server returned HTTP $HTTP (expected 200)"
fi

# TC-DIS-002: All services registered in Eureka
info "TC-DIS-002: Checking Eureka service registrations..."
EUREKA_APPS=$(curl -s -H "Accept: application/json" \
  --max-time 10 "http://localhost:8761/eureka/apps" 2>/dev/null)
EXPECTED_APPS=(CUSTOMERS-SERVICE VETS-SERVICE VISITS-SERVICE API-GATEWAY)
ALL_REGISTERED=true
for APP in "${EXPECTED_APPS[@]}"; do
  if echo "$EUREKA_APPS" | grep -qi "$APP"; then
    info "  Registered: $APP"
  else
    fail "TC-DIS-002: Service '$APP' NOT registered in Eureka"
    ALL_REGISTERED=false
  fi
done
if $ALL_REGISTERED; then
  pass "TC-DIS-002: All expected services registered in Eureka"
fi

# TC-VET-003: Vets Service health
info "TC-VET-003: Port-forwarding vets-service (8083)..."
port_forward vets-service 8083 8083
check_health "TC-VET-003" "http://localhost:8083/actuator/health" "Vets Service health endpoint"

# TC-VST-004: Visits Service health
info "TC-VST-004: Port-forwarding visits-service (8082)..."
port_forward visits-service 8082 8082
check_health "TC-VST-004" "http://localhost:8082/actuator/health" "Visits Service health endpoint"

# Customers Service health (bonus check)
info "Bonus: Port-forwarding customers-service (8081)..."
port_forward customers-service 8081 8081
check_health "BONUS-CST" "http://localhost:8081/actuator/health" "Customers Service health endpoint"

echo ""
echo "============================================================"
echo " Health Check Complete"
echo " PASSED: $PASS | FAILED: $FAIL"
echo "============================================================"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
