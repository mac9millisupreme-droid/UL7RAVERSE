#!/data/data/com.termux/files/usr/bin/bash
set +e

ROOT="$HOME/UL7RAVERSE"
cd "$ROOT" || exit 1

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/verification_artifacts/western_fair_convergence/$TS"
mkdir -p "$OUT"

exec > >(tee "$OUT/REPORT.txt") 2>&1

echo "============================================================"
echo " WESTERN FAIR OMNIPULSE × UL7RAVERSE CONVERGENCE"
echo "============================================================"
echo "TIME=$TS"
echo "HEAD=$(git rev-parse HEAD 2>/dev/null)"
echo

# ------------------------------------------------------------
# 1. FIND LATEST OMNIPULSE
# ------------------------------------------------------------
echo "=== 1. OMNIPULSE DISCOVERY ==="

LATEST="$(find verification_artifacts/omnipulse/force-live \
  -type f -name index.html 2>/dev/null |
  sort | tail -1)"

if [ -n "$LATEST" ]; then
  APP="$(dirname "$LATEST")"
  echo "OMNIPULSE_APP=$APP"

  grep -q "FIND YOUR FAIR" "$LATEST" &&
    echo "FIND_YOUR_FAIR=PASS" ||
    echo "FIND_YOUR_FAIR=FAIL"

  grep -q "BUILD YOUR FAIR" "$LATEST" &&
    echo "BUILD_YOUR_FAIR=PASS" ||
    echo "BUILD_YOUR_FAIR=FAIL"

  grep -q "UL7RAVERSE" "$LATEST" &&
    echo "UL7RAVERSE=PASS" ||
    echo "UL7RAVERSE=FAIL"

  grep -q "MAC9RECORDS" "$LATEST" &&
    echo "MAC9RECORDS=PASS" ||
    echo "MAC9RECORDS=FAIL"

  grep -q "independent digital companion" "$LATEST" &&
    echo "INDEPENDENT_POSITIONING=PASS" ||
    echo "INDEPENDENT_POSITIONING=UNPROVEN"
else
  echo "OMNIPULSE_APP=NOT_FOUND"
fi

echo

# ------------------------------------------------------------
# 2. OMNIPULSE LOCAL HTTP
# ------------------------------------------------------------
echo "=== 2. OMNIPULSE LOCAL ==="

OMNI_HTTP="$(curl -sS \
  -o "$OUT/omnipulse.html" \
  -w '%{http_code}' \
  --connect-timeout 3 \
  --max-time 5 \
  http://127.0.0.1:8899/ 2>/dev/null)"

echo "OMNIPULSE_HTTP=$OMNI_HTTP"

if [ "$OMNI_HTTP" = "200" ]; then
  echo "OMNIPULSE_LOCAL=PASS"
else
  echo "OMNIPULSE_LOCAL=FAIL"
fi

echo

# ------------------------------------------------------------
# 3. UL7RA VERIFY LOCAL
# ------------------------------------------------------------
echo "=== 3. UL7RA VERIFY LOCAL ==="

VERIFY_HTTP="$(curl -sS \
  -o "$OUT/verify_health.json" \
  -w '%{http_code}' \
  --connect-timeout 3 \
  --max-time 5 \
  http://127.0.0.1:8787/health 2>/dev/null)"

echo "VERIFY_HTTP=$VERIFY_HTTP"
cat "$OUT/verify_health.json" 2>/dev/null
echo

# ------------------------------------------------------------
# 4. NAMED CLOUDFLARE TUNNEL
# ------------------------------------------------------------
echo "=== 4. NAMED TUNNEL ==="

cloudflared tunnel info ul7ra-verify \
  2>&1 | tee "$OUT/tunnel.txt"

TUNNEL_EXIT=${PIPESTATUS[0]}

if [ "$TUNNEL_EXIT" = "0" ]; then
  echo "NAMED_TUNNEL=PASS"
else
  echo "NAMED_TUNNEL=FAIL"
fi

echo

# ------------------------------------------------------------
# 5. VERIFY EXISTING DNS ROUTE
# ------------------------------------------------------------
echo "=== 5. DNS ROUTE ==="

cloudflared tunnel route dns ul7ra-verify verify.omnilucient.com \
  2>&1 | tee "$OUT/route.txt"

ROUTE_EXIT=${PIPESTATUS[0]}

if [ "$ROUTE_EXIT" = "0" ]; then
  echo "TUNNEL_ROUTE=PASS"
else
  echo "TUNNEL_ROUTE=FAIL"
fi

echo

# ------------------------------------------------------------
# 6. PUBLIC DNS — NO BLIND PROMOTION
# ------------------------------------------------------------
echo "=== 6. PUBLIC DNS ==="

DNS_CF="$(nslookup verify.omnilucient.com 1.1.1.1 2>&1)"
DNS_GOOGLE="$(nslookup verify.omnilucient.com 8.8.8.8 2>&1)"

echo "--- CLOUDFLARE ---"
echo "$DNS_CF"

echo "--- GOOGLE ---"
echo "$DNS_GOOGLE"

if echo "$DNS_CF" | grep -qE 'Address: [0-9]|Address: [0-9a-fA-F:]' &&
   echo "$DNS_GOOGLE" | grep -qE 'Address: [0-9]|Address: [0-9a-fA-F:]'; then
  PUBLIC_DNS=PASS
else
  PUBLIC_DNS=BLOCKED
fi

echo "PUBLIC_DNS=$PUBLIC_DNS"
echo

# ------------------------------------------------------------
# 7. PUBLIC UL7RA VERIFY
# ------------------------------------------------------------
echo "=== 7. PUBLIC VERIFY ==="

PUBLIC_HTTP="$(curl -sS \
  -o "$OUT/public_verify.json" \
  -w '%{http_code}' \
  --connect-timeout 5 \
  --max-time 10 \
  https://verify.omnilucient.com/health 2>/dev/null)"

echo "PUBLIC_VERIFY_HTTP=$PUBLIC_HTTP"
cat "$OUT/public_verify.json" 2>/dev/null
echo

if [ "$PUBLIC_HTTP" = "200" ]; then
  PUBLIC_VERIFY=PASS
else
  PUBLIC_VERIFY=BLOCKED
fi

# ------------------------------------------------------------
# 8. LUCI TESTS
# ------------------------------------------------------------
echo "=== 8. LUCI TESTS ==="

pytest -q lucideploy/tests 2>&1 | tee "$OUT/luci_tests.txt"
LUCI_TEST_EXIT=${PIPESTATUS[0]}

if [ "$LUCI_TEST_EXIT" = "0" ]; then
  echo "LUCI_TESTS=PASS"
else
  echo "LUCI_TESTS=FAIL"
fi

echo

# ------------------------------------------------------------
# 9. FINAL GATE
# ------------------------------------------------------------
echo "=== 9. AUTHORITATIVE LUCI FINAL GATE ==="

if [ -x lucideploy/run_final_gate.sh ]; then
  lucideploy/run_final_gate.sh \
    2>&1 | tee "$OUT/final_gate.txt"

  GATE_EXIT=${PIPESTATUS[0]}
else
  echo "FINAL_GATE_SCRIPT=MISSING"
  GATE_EXIT=1
fi

echo "GATE_EXIT=$GATE_EXIT"
echo

# ------------------------------------------------------------
# 10. FINAL CONVERGENCE
# ------------------------------------------------------------
echo "============================================================"
echo " FINAL CONVERGENCE"
echo "============================================================"

echo "OMNIPULSE_LOCAL=$([ "$OMNI_HTTP" = "200" ] && echo PASS || echo FAIL)"
echo "FIND_YOUR_FAIR=$(grep -q "FIND YOUR FAIR" "$LATEST" 2>/dev/null && echo PASS || echo FAIL)"
echo "BUILD_YOUR_FAIR=$(grep -q "BUILD YOUR FAIR" "$LATEST" 2>/dev/null && echo PASS || echo FAIL)"
echo "UL7RAVERSE=$(grep -q "UL7RAVERSE" "$LATEST" 2>/dev/null && echo PASS || echo FAIL)"
echo "MAC9RECORDS=$(grep -q "MAC9RECORDS" "$LATEST" 2>/dev/null && echo PASS || echo FAIL)"

echo "LOCAL_VERIFY=$([ "$VERIFY_HTTP" = "200" ] && echo PASS || echo FAIL)"
echo "NAMED_TUNNEL=$([ "$TUNNEL_EXIT" = "0" ] && echo PASS || echo FAIL)"
echo "TUNNEL_ROUTE=$([ "$ROUTE_EXIT" = "0" ] && echo PASS || echo FAIL)"
echo "PUBLIC_DNS=$PUBLIC_DNS"
echo "PUBLIC_VERIFY=$PUBLIC_VERIFY"
echo "LUCI_TESTS=$([ "$LUCI_TEST_EXIT" = "0" ] && echo PASS || echo FAIL)"

echo

if [ "$OMNI_HTTP" = "200" ] &&
   grep -q "FIND YOUR FAIR" "$LATEST" 2>/dev/null &&
   grep -q "BUILD YOUR FAIR" "$LATEST" 2>/dev/null &&
   grep -q "UL7RAVERSE" "$LATEST" 2>/dev/null &&
   grep -q "MAC9RECORDS" "$LATEST" 2>/dev/null; then
  OMNIPULSE_STATUS=PASS
else
  OMNIPULSE_STATUS=FAIL
fi

echo "OMNIPULSE_STATUS=$OMNIPULSE_STATUS"

if [ "$OMNIPULSE_STATUS" = "PASS" ] &&
   [ "$VERIFY_HTTP" = "200" ] &&
   [ "$TUNNEL_EXIT" = "0" ] &&
   [ "$ROUTE_EXIT" = "0" ] &&
   [ "$PUBLIC_DNS" = "PASS" ] &&
   [ "$PUBLIC_VERIFY" = "PASS" ] &&
   [ "$LUCI_TEST_EXIT" = "0" ] &&
   [ "$GATE_EXIT" = "0" ]; then

  echo "WESTERN_FAIR_OMNIPULSE=READY"
  echo "PUBLIC_UL7RA_VERIFY=VERIFIED"
  echo "PRODUCTION=LUCI_AUTHORITY_REQUIRED"
  echo "FINAL_DECISION=SEE_AUTHORITATIVE_GATE"
else
  echo "WESTERN_FAIR_OMNIPULSE=$OMNIPULSE_STATUS"
  echo "PUBLIC_UL7RA_VERIFY=$PUBLIC_VERIFY"
  echo "PRODUCTION=BLOCKED"
  echo "PROMOTION=BLOCKED"
  echo "FINAL_DECISION=BLOCKED"
fi

echo "FAIL_CLOSED=TRUE"
echo "EVIDENCE=$OUT"
echo "============================================================"
