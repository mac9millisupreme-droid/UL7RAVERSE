#!/data/data/com.termux/files/usr/bin/bash
set +e

ROOT="$HOME/UL7RAVERSE"
cd "$ROOT" || exit 1

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/verification_artifacts/production_repair/$TS"
mkdir -p "$OUT"

exec > >(tee "$OUT/REPORT.txt") 2>&1

echo "============================================================"
echo " UL7RA VERIFY — PRODUCTION ROUTE REPAIR"
echo "============================================================"
echo "TIME=$TS"
echo "HEAD=$(git rev-parse HEAD 2>/dev/null)"
echo "HOSTNAME=verify.omnilucient.com"
echo "TUNNEL=ul7ra-verify"
echo

echo "=== 1. PRECHECK LOCAL SERVICE ==="
LOCAL_STATUS="$(curl -sS -o "$OUT/local_health.json" \
  -w '%{http_code}' \
  --connect-timeout 3 --max-time 5 \
  http://127.0.0.1:8787/health 2>/dev/null)"
echo "LOCAL_HTTP=$LOCAL_STATUS"
cat "$OUT/local_health.json" 2>/dev/null
echo

if [ "$LOCAL_STATUS" != "200" ]; then
  echo "FINAL_DECISION=BLOCKED"
  echo "REASON=LOCAL_VERIFY_HEALTH_FAILED"
  exit 1
fi

echo "=== 2. NAMED TUNNEL ==="
cloudflared tunnel info ul7ra-verify 2>&1 | tee "$OUT/tunnel_info.txt"
TUNNEL_INFO_EXIT=${PIPESTATUS[0]}
echo "TUNNEL_INFO_EXIT=$TUNNEL_INFO_EXIT"
echo

if [ "$TUNNEL_INFO_EXIT" != "0" ]; then
  echo "FINAL_DECISION=BLOCKED"
  echo "REASON=NAMED_TUNNEL_NOT_VERIFIED"
  exit 1
fi

echo "=== 3. CREATE/REPAIR DNS ROUTE ==="
cloudflared tunnel route dns ul7ra-verify verify.omnilucient.com \
  2>&1 | tee "$OUT/dns_route.txt"
DNS_ROUTE_EXIT=${PIPESTATUS[0]}
echo "DNS_ROUTE_EXIT=$DNS_ROUTE_EXIT"
echo

if [ "$DNS_ROUTE_EXIT" != "0" ]; then
  echo "FINAL_DECISION=BLOCKED"
  echo "REASON=DNS_ROUTE_OPERATION_FAILED"
  exit 1
fi

echo "=== 4. DNS PROPAGATION CHECK ==="
DNS_OK=0

for i in $(seq 1 12); do
  echo "--- DNS_ATTEMPT=$i"
  nslookup verify.omnilucient.com 8.8.8.8 2>&1 | tee "$OUT/dns_$i.txt"

  if nslookup verify.omnilucient.com 8.8.8.8 2>&1 |
       grep -qE 'Address: [0-9]|Address: [0-9a-fA-F:]'; then
    DNS_OK=1
    break
  fi

  sleep 5
done

echo "DNS_OK=$DNS_OK"
echo

if [ "$DNS_OK" != "1" ]; then
  echo "FINAL_DECISION=BLOCKED"
  echo "REASON=PUBLIC_DNS_NOT_RESOLVING"
  exit 1
fi

echo "=== 5. INDEPENDENT PUBLIC HEALTH ==="
PUBLIC_HTTP=000

for i in $(seq 1 12); do
  echo "--- PUBLIC_ATTEMPT=$i"

  PUBLIC_HTTP="$(curl -sS \
    -o "$OUT/public_health_$i.json" \
    -w '%{http_code}' \
    --connect-timeout 5 \
    --max-time 10 \
    https://verify.omnilucient.com/health 2>/dev/null)"

  echo "HTTP=$PUBLIC_HTTP"

  if [ "$PUBLIC_HTTP" = "200" ]; then
    cat "$OUT/public_health_$i.json"
    echo
    break
  fi

  sleep 5
done

echo "PUBLIC_HTTP_FINAL=$PUBLIC_HTTP"
echo

if [ "$PUBLIC_HTTP" != "200" ]; then
  echo "FINAL_DECISION=BLOCKED"
  echo "REASON=PUBLIC_HEALTH_NOT_VERIFIED"
  exit 1
fi

echo "=== 6. AUTHORITATIVE LUCI FINAL GATE ==="

if [ -x lucideploy/run_final_gate.sh ]; then
  lucideploy/run_final_gate.sh 2>&1 | tee "$OUT/luci_final_gate.txt"
  GATE_EXIT=${PIPESTATUS[0]}
else
  echo "LUCI_FINAL_GATE_SCRIPT_MISSING"
  GATE_EXIT=1
fi

echo "LUCI_GATE_EXIT=$GATE_EXIT"
echo

echo "============================================================"
echo " FINAL CONVERGENCE"
echo "============================================================"
echo "LOCAL_VERIFY=PASS"
echo "NAMED_TUNNEL=PASS"
echo "DNS=PASS"
echo "PUBLIC_HTTP=$PUBLIC_HTTP"
echo

if [ "$PUBLIC_HTTP" = "200" ] && \
   grep -qE '"production"[[:space:]]*:[[:space:]]*"PASS"|PRODUCTION=PASS|PRODUCTION_UNLOCK=1' \
   "$OUT/luci_final_gate.txt" 2>/dev/null; then

  echo "PRODUCTION=PASS"
  echo "PROMOTION=AUTHORIZED_BY_LUCI_EVIDENCE"
  echo "FINAL_DECISION=PASS"
else
  echo "PRODUCTION=BLOCKED"
  echo "PROMOTION=BLOCKED"
  echo "FINAL_DECISION=BLOCKED"
fi

echo "FAIL_CLOSED=TRUE"
echo "EVIDENCE=$OUT"
echo "============================================================"
