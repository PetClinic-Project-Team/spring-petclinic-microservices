#!/usr/bin/env bash
# API End-to-End Tests — TC-GW-*, TC-CST-*, TC-VET-*, TC-VST-*
# Usage: ./tests/e2e/api-tests.sh [GATEWAY_URL]
# Example: ./tests/e2e/api-tests.sh http://abc123.us-east-1.elb.amazonaws.com

set -o pipefail

NAMESPACE="spring-petclinic"
PASS=0
FAIL=0
CREATED_OWNER_ID=""
CREATED_VISIT_ID=""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS++)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL++)); }
warn() { echo -e "${YELLOW}[KNOWN DEFECT]${NC} $1"; }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
section() { echo -e "\n${CYAN}--- $1 ---${NC}"; }

# Resolve gateway URL
if [ -n "$1" ]; then
  GW_BASE="$1"
else
  GW_HOSTNAME=$(kubectl get svc api-gateway -n "$NAMESPACE" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
  GW_IP=$(kubectl get svc api-gateway -n "$NAMESPACE" \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
  ENDPOINT="${GW_HOSTNAME:-$GW_IP}"
  if [ -z "$ENDPOINT" ]; then
    echo -e "${RED}ERROR:${NC} Cannot determine API Gateway URL. Pass it as argument or ensure LoadBalancer IP is assigned."
    exit 1
  fi
  GW_BASE="http://$ENDPOINT"
fi

echo "============================================================"
echo " API End-to-End Tests"
echo " Gateway: $GW_BASE"
echo " $(date)"
echo "============================================================"

check_http() {
  local TC=$1 METHOD=$2 URL=$3 DESC=$4 EXPECTED_CODE=${5:-200}
  local EXTRA_ARGS=("${@:6}")
  HTTP_CODE=$(curl -s -o /tmp/api_test_response.json -w "%{http_code}" \
    -X "$METHOD" "${EXTRA_ARGS[@]}" --max-time 15 "$URL" 2>/dev/null)
  if [ "$HTTP_CODE" = "$EXPECTED_CODE" ] || \
     { [ "$EXPECTED_CODE" = "200" ] && [ "$HTTP_CODE" = "201" ]; }; then
    pass "$TC: $DESC (HTTP $HTTP_CODE)"
    return 0
  else
    fail "$TC: $DESC — Expected HTTP $EXPECTED_CODE, got HTTP $HTTP_CODE"
    return 1
  fi
}

check_json_field() {
  local TC=$1 FIELD=$2 DESC=$3
  if python3 -c "import sys,json; d=json.load(open('/tmp/api_test_response.json')); \
    v=d if not isinstance(d,list) else d[0]; print(v.get('$FIELD',''))" 2>/dev/null | grep -q .; then
    pass "$TC: $DESC — field '$FIELD' present"
  else
    fail "$TC: $DESC — field '$FIELD' missing in response"
  fi
}

# -------------------------------------------------------
section "TC-GW: API Gateway Routing Tests"
# -------------------------------------------------------

# TC-GW-001: Gateway homepage
info "TC-GW-001: Gateway homepage..."
check_http "TC-GW-001" "GET" "$GW_BASE" "Gateway root returns HTTP 2xx"

# TC-GW-002: Route to customers API
info "TC-GW-002: Gateway → customers route..."
check_http "TC-GW-002" "GET" "$GW_BASE/api/customer/owners" "Gateway routes to customers-service"

# TC-GW-003: Route to vets API
info "TC-GW-003: Gateway → vets route..."
check_http "TC-GW-003" "GET" "$GW_BASE/api/vet/vets" "Gateway routes to vets-service"

# TC-GW-004: Route to visits API
info "TC-GW-004: Gateway → visits route..."
check_http "TC-GW-004" "GET" "$GW_BASE/api/visit/owners/1/pets/1/visits" "Gateway routes to visits-service"

# -------------------------------------------------------
section "TC-CST: Customers Service Tests"
# -------------------------------------------------------

# TC-CST-001: List all owners
info "TC-CST-001: List all owners..."
if check_http "TC-CST-001" "GET" "$GW_BASE/api/customer/owners" "List all owners returns HTTP 200"; then
  OWNER_COUNT=$(python3 -c "import json; print(len(json.load(open('/tmp/api_test_response.json'))))" 2>/dev/null || echo 0)
  info "  Owner count: $OWNER_COUNT"
  if [ "$OWNER_COUNT" -gt 0 ]; then
    pass "TC-CST-001b: Owners list is non-empty ($OWNER_COUNT owners from seed data)"
  else
    fail "TC-CST-001b: Owners list is empty — seed data may not be loaded"
  fi
fi

# TC-CST-002: Get owner by ID
info "TC-CST-002: Get owner by ID=1..."
if check_http "TC-CST-002" "GET" "$GW_BASE/api/customer/owners/1" "Get owner by ID"; then
  check_json_field "TC-CST-002b" "id" "Owner ID field present"
fi

# TC-CST-003: Create new owner
info "TC-CST-003: Create new owner..."
CREATE_PAYLOAD='{"firstName":"E2E","lastName":"TestOwner","address":"100 Test Ave","city":"TestCity","telephone":"5550000001"}'
HTTP_CREATE=$(curl -s -o /tmp/api_test_response.json -w "%{http_code}" \
  -X POST "$GW_BASE/api/customer/owners" \
  -H "Content-Type: application/json" \
  -d "$CREATE_PAYLOAD" --max-time 15 2>/dev/null)
if [ "$HTTP_CREATE" = "200" ] || [ "$HTTP_CREATE" = "201" ]; then
  CREATED_OWNER_ID=$(python3 -c "import json; print(json.load(open('/tmp/api_test_response.json')).get('id',''))" 2>/dev/null)
  pass "TC-CST-003: New owner created (HTTP $HTTP_CREATE, ID: ${CREATED_OWNER_ID:-unknown})"
else
  fail "TC-CST-003: Create owner failed (HTTP $HTTP_CREATE)"
fi

# TC-CST-004: Get owner not found (negative test) — DEF-003: upstream returns 200 instead of 404
info "TC-CST-004: Get owner with non-existent ID (negative)..."
HTTP_404=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 \
  "$GW_BASE/api/customer/owners/99999" 2>/dev/null)
if [ "$HTTP_404" = "404" ]; then
  pass "TC-CST-004: Non-existent owner returns 404 (HTTP 404)"
else
  warn "TC-CST-004: DEF-003 — Non-existent owner returned HTTP $HTTP_404 (expected 404). Known upstream Spring PetClinic bug — not blocking."
fi

# TC-CST-005: Verify owner has pets field
info "TC-CST-005: Check owner response has pets array..."
curl -s "$GW_BASE/api/customer/owners/1" -o /tmp/api_test_response.json --max-time 15 2>/dev/null
if python3 -c "import json; d=json.load(open('/tmp/api_test_response.json')); assert 'pets' in d" 2>/dev/null; then
  pass "TC-CST-005: Owner response contains 'pets' array field"
else
  fail "TC-CST-005: Owner response missing 'pets' array field"
fi

# TC-CST-006: List pet types
info "TC-CST-006: Get pet types..."
if check_http "TC-CST-006" "GET" "$GW_BASE/api/customer/petTypes" "List pet types returns HTTP 200"; then
  PET_TYPE_COUNT=$(python3 -c "import json; print(len(json.load(open('/tmp/api_test_response.json'))))" 2>/dev/null || echo 0)
  info "  Pet types available: $PET_TYPE_COUNT"
  [ "$PET_TYPE_COUNT" -gt 0 ] && \
    pass "TC-CST-006b: Pet types list non-empty ($PET_TYPE_COUNT types)" || \
    fail "TC-CST-006b: Pet types list is empty"
fi

# -------------------------------------------------------
section "TC-VET: Vets Service Tests"
# -------------------------------------------------------

# TC-VET-001: List all vets
info "TC-VET-001: List all vets..."
if check_http "TC-VET-001" "GET" "$GW_BASE/api/vet/vets" "List all vets returns HTTP 200"; then
  VET_COUNT=$(python3 -c "import json; print(len(json.load(open('/tmp/api_test_response.json'))))" 2>/dev/null || echo 0)
  info "  Vet count: $VET_COUNT"
  [ "$VET_COUNT" -gt 0 ] && \
    pass "TC-VET-001b: Vets list non-empty ($VET_COUNT vets from seed data)" || \
    fail "TC-VET-001b: Vets list is empty — seed data may not be loaded"
fi

# TC-VET-002: Vets have specialties field
info "TC-VET-002: Verify vet response contains specialties field..."
curl -s "$GW_BASE/api/vet/vets" -o /tmp/api_test_response.json --max-time 15 2>/dev/null
if python3 -c "import json; d=json.load(open('/tmp/api_test_response.json')); assert 'specialties' in d[0]" 2>/dev/null; then
  pass "TC-VET-002: Vet response contains 'specialties' field"
else
  fail "TC-VET-002: Vet response missing 'specialties' field"
fi

# -------------------------------------------------------
section "TC-VST: Visits Service Tests"
# -------------------------------------------------------

# TC-VST-001: List visits for pet
info "TC-VST-001: List visits for owner 1 / pet 1..."
check_http "TC-VST-001" "GET" "$GW_BASE/api/visit/owners/1/pets/1/visits" "List visits returns HTTP 200"

# TC-VST-002: Create a new visit
info "TC-VST-002: Create a new visit..."
VISIT_PAYLOAD='{"date":"2026-05-14","description":"E2E automated test visit"}'
HTTP_VISIT=$(curl -s -o /tmp/api_test_response.json -w "%{http_code}" \
  -X POST "$GW_BASE/api/visit/owners/1/pets/1/visits" \
  -H "Content-Type: application/json" \
  -d "$VISIT_PAYLOAD" --max-time 15 2>/dev/null)
if [ "$HTTP_VISIT" = "200" ] || [ "$HTTP_VISIT" = "201" ]; then
  CREATED_VISIT_ID=$(python3 -c "import json; print(json.load(open('/tmp/api_test_response.json')).get('id',''))" 2>/dev/null)
  pass "TC-VST-002: Visit created (HTTP $HTTP_VISIT, ID: ${CREATED_VISIT_ID:-unknown})"
else
  fail "TC-VST-002: Create visit failed (HTTP $HTTP_VISIT)"
fi

# TC-VST-003: Verify visit persists
if [ -n "$CREATED_VISIT_ID" ]; then
  info "TC-VST-003: Verifying visit appears in list after creation..."
  VISITS_RESPONSE=$(curl -s "$GW_BASE/api/visit/owners/1/pets/1/visits" --max-time 15 2>/dev/null)
  if echo "$VISITS_RESPONSE" | grep -q "E2E automated test visit"; then
    pass "TC-VST-003: Created visit persists and appears in visit history"
  else
    fail "TC-VST-003: Created visit not found in visit history"
  fi
fi

# -------------------------------------------------------
section "TC-GENAI: GenAI Chatbot Service Tests"
# -------------------------------------------------------

# TC-GENAI-003: Chatbot responds via API Gateway
info "TC-GENAI-003: Chatbot responds to question via API Gateway..."
CHAT_PAYLOAD='{"message":"Which vets specialize in dentistry?"}'
HTTP_CHAT=$(curl -s -o /tmp/api_test_response.json -w "%{http_code}" \
  -X POST "$GW_BASE/api/genai/chatclient" \
  -H "Content-Type: application/json" \
  -d "$CHAT_PAYLOAD" --max-time 60 2>/dev/null)
if [ "$HTTP_CHAT" = "200" ]; then
  CHAT_BODY=$(cat /tmp/api_test_response.json 2>/dev/null)
  if echo "$CHAT_BODY" | grep -qi "vet\|dentist\|speciali\|Linda\|Douglas"; then
    pass "TC-GENAI-003: Chatbot returned AI-generated response via API Gateway (HTTP 200)"
  else
    fail "TC-GENAI-003: Chatbot responded HTTP 200 but body looks unexpected: $CHAT_BODY"
  fi
else
  fail "TC-GENAI-003: Chatbot endpoint returned HTTP $HTTP_CHAT (expected 200) — check genai-service and openai-secret"
fi

echo ""
echo "============================================================"
echo " API Tests Complete"
echo " PASSED: $PASS | FAILED: $FAIL"
echo "============================================================"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
