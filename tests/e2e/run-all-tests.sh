#!/usr/bin/env bash
# Master E2E Test Runner — Spring PetClinic Microservices on AWS EKS
# P9 — QA & Demo Lead
# Usage: ./tests/e2e/run-all-tests.sh [GATEWAY_URL]
# Example: ./tests/e2e/run-all-tests.sh http://abc.us-east-1.elb.amazonaws.com

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_FILE="$SCRIPT_DIR/../../docs/test-run-report.txt"
START_TIME=$(date +%s)

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

TOTAL_PASS=0
TOTAL_FAIL=0
SUITE_RESULTS=()

run_suite() {
  local NAME=$1 SCRIPT=$2
  shift 2
  local ARGS=("$@")
  echo -e "\n${CYAN}${BOLD}════════════════════════════════════════${NC}"
  echo -e "${CYAN}${BOLD} Running: $NAME${NC}"
  echo -e "${CYAN}${BOLD}════════════════════════════════════════${NC}"

  if bash "$SCRIPT" "${ARGS[@]}"; then
    SUITE_RESULTS+=("${GREEN}[PASS]${NC} $NAME")
    ((TOTAL_PASS++))
  else
    SUITE_RESULTS+=("${RED}[FAIL]${NC} $NAME")
    ((TOTAL_FAIL++))
  fi
}

echo -e "${BOLD}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   Spring PetClinic Microservices — E2E Test Suite        ║"
echo "║   P9 — QA & Demo Lead                                   ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "  Started : $(date)"
echo "  Cluster : $(kubectl config current-context 2>/dev/null || echo 'unknown')"
echo "  Namespace: spring-petclinic"
[ -n "$1" ] && echo "  Gateway : $1"
echo ""

# Make all scripts executable
chmod +x "$SCRIPT_DIR"/*.sh

# Suite 1: Infrastructure Validation
run_suite "Infrastructure Validation (TC-INF-*)" "$SCRIPT_DIR/k8s-validation.sh"

# Suite 2: Service Health Checks
run_suite "Service Health Checks (TC-CFG-*, TC-DIS-*, TC-VET-003, TC-VST-004)" "$SCRIPT_DIR/health-check.sh"

# Suite 3: API End-to-End Tests
if [ -n "$1" ]; then
  run_suite "API End-to-End Tests (TC-GW-*, TC-CST-*, TC-VET-*, TC-VST-*)" \
    "$SCRIPT_DIR/api-tests.sh" "$1"
else
  run_suite "API End-to-End Tests (TC-GW-*, TC-CST-*, TC-VET-*, TC-VST-*)" \
    "$SCRIPT_DIR/api-tests.sh"
fi

# Suite 4: Observability Stack
run_suite "Observability Stack (TC-OBS-001, TC-OBS-002, TC-OBS-003, TC-OBS-005)" \
  "$SCRIPT_DIR/monitoring-check.sh"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║                 TEST RUN SUMMARY                        ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Completed : $(date)"
echo "  Duration  : ${DURATION}s"
echo ""
echo "  Test Suites:"
for RESULT in "${SUITE_RESULTS[@]}"; do
  echo -e "    $RESULT"
done
echo ""

TOTAL_SUITES=$((TOTAL_PASS + TOTAL_FAIL))
if [ "$TOTAL_FAIL" -eq 0 ]; then
  echo -e "  ${GREEN}${BOLD}ALL $TOTAL_SUITES SUITES PASSED${NC}"
  OVERALL="PASS"
else
  echo -e "  ${RED}${BOLD}$TOTAL_FAIL/$TOTAL_SUITES SUITES FAILED${NC}"
  OVERALL="FAIL"
fi

echo ""
echo "  Next Steps:"
if [ "$OVERALL" = "PASS" ]; then
  echo "    ✓ Run manual test cases: docs/test-cases.md (TC-DB-*, TC-E2E-*, manual OBS tests)"
  echo "    ✓ Record results in: docs/test-results.md"
  echo "    ✓ Rehearse demo: docs/demo-script.md"
else
  echo "    ✗ Investigate failures above"
  echo "    ✗ Check pod logs: kubectl logs -n spring-petclinic -l app=<service> --tail=50"
  echo "    ✗ Check events:   kubectl get events -n spring-petclinic --sort-by='.lastTimestamp'"
fi

echo ""
echo -e "${YELLOW}Saving report to $REPORT_FILE${NC}"
{
  echo "Spring PetClinic — E2E Test Run Report"
  echo "Date: $(date)"
  echo "Overall: $OVERALL"
  echo "Suites: $TOTAL_PASS passed / $TOTAL_FAIL failed / $TOTAL_SUITES total"
  echo "Duration: ${DURATION}s"
  echo ""
  echo "--- kubectl get pods -n spring-petclinic ---"
  kubectl get pods -n spring-petclinic 2>&1
  echo ""
  echo "--- kubectl get svc -n spring-petclinic ---"
  kubectl get svc -n spring-petclinic 2>&1
} > "$REPORT_FILE" 2>&1

[ "$TOTAL_FAIL" -eq 0 ] && exit 0 || exit 1
