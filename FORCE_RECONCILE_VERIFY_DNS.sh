#!/data/data/com.termux/files/usr/bin/bash
set +e

ROOT="$HOME/UL7RAVERSE"
cd "$ROOT" || exit 1

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/verification_artifacts/dns_reconcile/$TS"
mkdir -p "$OUT"
exec > >(tee "$OUT/REPORT.txt") 2>&1

HOST="verify.omnilucient.com"
TUNNEL="ul7ra-verify"

echo "============================================================"
echo " UL7RA VERIFY — DNS ROUTE RECONCILIATION"
echo "============================================================"
echo "TIME=$TS"
echo "HEAD=$(git rev-parse HEAD 2>/dev/null)"
echo "HOST=$HOST"
echo "TUNNEL=$TUNNEL"
echo

echo "=== 1. LOCAL SERVICE ==="
LOCAL_HTTP="$(curl -sS -o "$OUT/local.json" -w '%{http_code}' \
  --connect-timeout 3 --max-time 5 \
  http://127.0.0.1:8787/health 2>/dev/null)"
echo "LOCAL_HTTP=$LOCAL_HTTP"
cat "$OUT/local.json" 2>/dev/null
echo

[ "$LOCAL_HTTP" = "200" ] || {
  echo "FINAL_DECISION=BLOCKED"
  echo "REASON=LOCAL_VERIFY_FAILED"
  exit 1
}

echo "=== 2. NAMED TUNNEL ==="
cloudflared tunnel info "$TUNNEL" 2>&1 | tee "$OUT/tunnel_info.txt"
TUNNEL_EXIT=${PIPESTATUS[0]}
echo "TUNNEL_EXIT=$TUNNEL_EXIT"
echo

[ "$TUNNEL_EXIT" = "0" ] || {
  echo "FINAL_DECISION=BLOCKED"
  echo "REASON=NAMED_TUNNEL_FAILED"
  exit 1
}

echo "=== 3. FORCE DNS ROUTE RECONCILIATION ==="
cloudflared tunnel route dns --overwrite-dns "$TUNNEL" "$HOST" \
  2>&1 | tee "$OUT/dns_reconcile.txt"
ROUTE_EXIT=${PIPESTATUS[0]}
echo "ROUTE_EXIT=$ROUTE_EXIT"
echo

if [ "$ROUTE_EXIT" != "0" ]; then
  echo "=== ROUTE HELP / FLAG VALIDATION ==="
  cloudflared tunnel route dns --help 2>&1 | head -80
  echo
  echo "FINAL_DECISION=BLOCKED"
  echo "REASON=DNS_RECONCILIATION_FAILED"
  exit 1
fi

echo "=== 4. DNS VERIFICATION ==="
DNS_OK=0

for i in $(seq 1 12); do
  echo "--- ATTEMPT=$i"

  echo "CLOUDFLARE:"
  nslookup "$HOST" 1.1.1.1 2>&1

  echo "GOOGLE:"
  nslookup "$HOST" 8.8.8.8 2>&1

  CF="$(nslookup "$HOST" 1.1.1.1 2>&1)"
  GOOGLE="$(nslookup "$HOST" 8.8.8.8 2>&1)"

  if echo "$CF" | grep -qE 'Address: [0-9]|Address: [0-9a-fA-F:]' &&
     echo "$GOOGLE" | grep -qE 'Address: [0-9]|Address: [0-9a-fA-F:]'; then
    DNS_OK=1
    break
  fi

  sleep 5
done

echo "DNS_OK=$DNS_OK"
echo

[ "$DNS_OK" = "1" ] || {
  echo "FINAL_DECISION=BLOCKED"
  echo "REASON=PUBLIC_DNS_STILL_NXDOMAIN"
  echo "EVIDENCE=$OUT"
  exit 1
}

echo "=== 5. INDEPENDENT PUBLIC HTTPS ==="
PUBLIC_HTTP=000

for i in $(seq 1 12); do
  echo "--- PUBLIC_ATTEMPT=$i"

  PUBLIC_HTTP="$(curl -sS \
    -o "$OUT/public_$i.json" \
    -w '%{http_code}' \
    --connect-timeout 5 \
    --max-time 10 \
    "https://$HOST/health" 2>/dev/null)"

  echo "HTTP=$PUBLIC_HTTP"

  if [ "$PUBLIC_HTTP" = "200" ]; then
    cat "$OUT/public_$i.json"
    echo
    break
  fi

  sleep 5
done

echo "PUBLIC_HTTP=$PUBLIC_HTTP"
echo

[ "$PUBLIC_HTTP" = "200" ] || {
  echo "FINAL_DECISION=BLOCKED"
  echo "REASON=PUBLIC_HEALTH_FAILED"
  echo "EVIDENCE=$OUT"
  exit 1
}

echo "=== 6. AUTHORITATIVE LUCI FINAL GATE ==="

if [ -x lucideploy/run_final_gate.sh ]; then
  lucideploy/run_final_gate.sh 2>&1 | tee "$OUT/luci_final_gate.txt"
  LUCI_EXIT=${PIPESTATUS[0]}
else
  echo "LUCI_FINAL_GATE_MISSING"
  LUCI_EXIT=1
fi

echo "LUCI_EXIT=$LUCI_EXIT"
echo

echo "============================================================"
echo " FINAL CONVERGENCE"
echo "============================================================"
echo "LOCAL_VERIFY=PASS"
echo "NAMED_TUNNEL=PASS"
echo "DNS=PASS"
echo "PUBLIC_HTTP=200"
echo "LUCI_EXIT=$LUCI_EXIT"

if [ "$LUCI_EXIT" = "0" ] && \
   grep -qE 'PRODUCTION.*PASS|production.*PASS|PRODUCTION_UNLOCK=1' \
   "$OUT/luci_final_gate.txt" 2>/dev/null; then
  echo "PRODUCTION=PASS"
  echo "PROMOTION=AUTHORIZED"
  echo "FINAL_DECISION=PASS"
else
  echo "PRODUCTION=BLOCKED"
  echo "PROMOTION=BLOCKED"
  echo "FINAL_DECISION=BLOCKED"
fi

echo "FAIL_CLOSED=TRUE"
echo "EVIDENCE=$OUT"
echo "============================================================"
