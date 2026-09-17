#!/data/data/com.termux/files/usr/bin/bash
set +e

ROOT="$HOME/UL7RAVERSE"
cd "$ROOT" || exit 1

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/verification_artifacts/luci_one_shot/$TS"
mkdir -p "$OUT"

exec > >(tee "$OUT/REPORT.txt") 2>&1

echo "============================================================"
echo " UL7RAVERSE — LUCI ONE-SHOT AUTHORITY DIAGNOSTIC"
echo "============================================================"
echo "TIME=$TS"
echo "COMMIT=$(git rev-parse HEAD 2>/dev/null)"
echo

echo "=== 1. LUCI NATIVE CLI ==="
if [ -f lucideploy/cli/main.py ]; then
  echo "LUCI_CLI=FOUND"
  (
    cd lucideploy
    PYTHONPATH=. python cli/main.py --help
  )
  CLI_EXIT=$?
  echo "LUCI_CLI_EXIT=$CLI_EXIT"
else
  echo "LUCI_CLI=MISSING"
  CLI_EXIT=99
fi
echo

echo "=== 2. LUCI TEST SUITE ==="
pytest -q lucideploy/tests
TEST_EXIT=$?
echo "LUCI_TEST_EXIT=$TEST_EXIT"
echo

echo "=== 3. LUCI FINAL GATE ==="
if [ -x lucideploy/run_final_gate.sh ]; then
  ./lucideploy/run_final_gate.sh
  GATE_EXIT=$?
else
  echo "FINAL_GATE_SCRIPT=MISSING_OR_NOT_EXECUTABLE"
  GATE_EXIT=99
fi
echo "FINAL_GATE_EXIT=$GATE_EXIT"
echo

echo "=== 4. AUTHORITATIVE STATE ==="
if [ -f lucideploy/state/STATE.json ]; then
  cat lucideploy/state/STATE.json
else
  echo "STATE_JSON=MISSING"
fi
echo

echo "=== 5. AUTHORITATIVE FINAL GATE ==="
if [ -f lucideploy/evidence/final_gate.json ]; then
  cat lucideploy/evidence/final_gate.json
else
  echo "FINAL_GATE_JSON=MISSING"
fi
echo

echo "=== 6. CONTRACT ==="
if [ -f lucideploy/contracts/CONTRACT.json ]; then
  cat lucideploy/contracts/CONTRACT.json
else
  echo "CONTRACT_JSON=MISSING"
fi
echo

echo "=== 7. GATES ==="
if [ -f lucideploy/contracts/GATES.json ]; then
  cat lucideploy/contracts/GATES.json
else
  echo "GATES_JSON=MISSING"
fi
echo

echo "=== 8. OMNIPULSE LOCAL SURFACE ==="
LATEST="$(find verification_artifacts/omnipulse/force-live \
  -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
  sort | tail -1)"

echo "LATEST=$LATEST"

if [ -f "$LATEST/app/index.html" ]; then
  echo "INDEX=FOUND"
  grep -q 'FIND YOUR FAIR' "$LATEST/app/index.html" &&
    echo "FIND_YOUR_FAIR=PASS" ||
    echo "FIND_YOUR_FAIR=FAIL"

  grep -q 'UL7RAVERSE' "$LATEST/app/index.html" &&
    echo "UL7RAVERSE=PASS" ||
    echo "UL7RAVERSE=FAIL"

  grep -q 'MAC9RECORDS' "$LATEST/app/index.html" &&
    echo "MAC9RECORDS=PASS" ||
    echo "MAC9RECORDS=FAIL"

  grep -q 'BUILD YOUR FAIR' "$LATEST/app/index.html" &&
    echo "BUILD_YOUR_FAIR=PASS" ||
    echo "BUILD_YOUR_FAIR=FAIL"
else
  echo "INDEX=MISSING"
fi
echo

echo "=== 9. LOCAL HTTP ==="
HTTP="$(curl -sS -o "$OUT/local.html" \
  -w '%{http_code}' \
  --max-time 5 \
  http://127.0.0.1:8899 2>/dev/null)"

echo "LOCAL_HTTP=$HTTP"

if [ "$HTTP" = "200" ]; then
  grep -q 'FIND YOUR FAIR' "$OUT/local.html" &&
    echo "LOCAL_CONTENT=PASS" ||
    echo "LOCAL_CONTENT=FAIL"
else
  echo "LOCAL_CONTENT=UNVERIFIED"
fi
echo

echo "=== 10. PUBLIC NETWORK ==="
echo "PUBLIC_REACHABILITY=UNVERIFIED"
echo "NOTE=No Cloudflare mutation performed by this script."
echo

echo "=== 11. REVENUE / PRODUCTION AUTHORITY ==="
echo "PAYMENT_VERIFIED=0"
echo "VERIFIED_REVENUE_CAD=0"
echo "REAL_VISITOR=0"
echo "REAL_VENDOR=0"
echo "PROOF_OK=0"
echo "PRODUCTION_UNLOCK=0"
echo

echo "=== 12. MACHINE SUMMARY ==="

if [ "$TEST_EXIT" = "0" ]; then
  LUCI_TESTS="PASS"
else
  LUCI_TESTS="FAIL"
fi

if [ "$HTTP" = "200" ]; then
  LOCAL="PASS"
else
  LOCAL="UNVERIFIED"
fi

echo "LUCI_TESTS=$LUCI_TESTS"
echo "LUCI_CLI_EXIT=$CLI_EXIT"
echo "FINAL_GATE_EXIT=$GATE_EXIT"
echo "LOCAL_SURFACE=$LOCAL"
echo "PUBLIC_REACHABILITY=UNVERIFIED"

if [ "$TEST_EXIT" = "0" ] && [ "$HTTP" = "200" ]; then
  echo "LOCAL_CONVERGENCE=PASS"
else
  echo "LOCAL_CONVERGENCE=BLOCKED"
fi

echo
echo "=== FINAL DECISION ==="

if [ "$TEST_EXIT" = "0" ] && [ "$HTTP" = "200" ]; then
  echo "FINAL_DECISION=TEST"
  echo "REASON=LUCI_TESTS_AND_LOCAL_SURFACE_PASS_PUBLIC_REACHABILITY_UNVERIFIED"
else
  echo "FINAL_DECISION=BLOCKED"
  echo "REASON=LOCAL_LUCI_OR_SURFACE_FAILURE"
fi

echo
echo "EVIDENCE_DIR=$OUT"
echo "REPORT=$OUT/REPORT.txt"
echo "============================================================"
