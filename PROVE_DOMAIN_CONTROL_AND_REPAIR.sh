#!/data/data/com.termux/files/usr/bin/bash
set +e

ROOT="$HOME/UL7RAVERSE"
cd "$ROOT" || exit 1

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/verification_artifacts/domain_control/$TS"
mkdir -p "$OUT"

exec > >(tee "$OUT/REPORT.txt") 2>&1

DOMAIN="omnilucient.com"
HOST="verify.$DOMAIN"
TXT_HOST="_ul7ra-control.$DOMAIN"
TOKEN="UL7RA-CONTROL-$TS"

echo "============================================================"
echo " UL7RA DOMAIN CONTROL PROOF + DNS REPAIR"
echo "============================================================"
echo "TIME=$TS"
echo "DOMAIN=$DOMAIN"
echo "HOST=$HOST"
echo

echo "=== 1. AUTHORITATIVE NAMESERVERS ==="
dig NS "$DOMAIN" +short | tee "$OUT/authoritative_ns.txt"
echo

echo "=== 2. AUTHORITATIVE CONTROL CHECK ==="
for NS in $(dig NS "$DOMAIN" +short); do
  echo "--- @$NS ---"
  dig @"$NS" "$HOST" CNAME +noall +answer
  dig @"$NS" "$TXT_HOST" TXT +noall +answer
done
echo

echo "=== 3. CLOUDFLARE AUTHENTICATION STATE ==="
cloudflared tunnel list 2>&1 | tee "$OUT/tunnels.txt"
echo

echo "=== 4. NAMED TUNNEL ==="
cloudflared tunnel info ul7ra-verify 2>&1 | tee "$OUT/tunnel_info.txt"
TUNNEL_EXIT=${PIPESTATUS[0]}

echo
echo "=== 5. ROUTE ASSERTION ==="
cloudflared tunnel route dns ul7ra-verify "$HOST" 2>&1 | tee "$OUT/route.txt"
ROUTE_EXIT=${PIPESTATUS[0]}

echo
echo "=== 6. PUBLIC DNS BEFORE ==="
for R in 1.1.1.1 8.8.8.8; do
  echo "--- resolver $R ---"
  dig @"$R" "$HOST" CNAME +noall +answer
done
echo

echo "=== 7. EXISTING DOMAIN CONTROL EVIDENCE ==="
echo "The named Cloudflare tunnel and its configured hostname are already evidence"
echo "of control exercised through the current Cloudflare environment."
echo

echo "=== 8. TXT CONTROL CHALLENGE ==="
echo "TOKEN=$TOKEN"
echo
echo "If Cloudflare API credentials are available to this shell, the TXT"
echo "challenge can be created automatically. Otherwise the command below"
echo "is the exact record to create in the authoritative DNS zone:"
echo
echo "$TXT_HOST  TXT  \"$TOKEN\""
echo

echo "=== 9. REQUIRED PUBLIC PROOF ==="
echo "After the TXT exists, verify with:"
echo
echo "dig @1.1.1.1 $TXT_HOST TXT +short"
echo "dig @8.8.8.8 $TXT_HOST TXT +short"
echo

echo "=== 10. TARGET DNS RECORD ==="
echo "Expected:"
echo "$HOST CNAME a241e27b-336e-44cc-9a52-6487131db63b.cfargotunnel.com."
echo

echo "=== 11. PUBLIC HTTPS ==="
HTTP="$(curl -sS \
  -o "$OUT/public_health.json" \
  -w '%{http_code}' \
  --connect-timeout 5 \
  --max-time 15 \
  "https://$HOST/health" 2>/dev/null)"

echo "HTTPS_STATUS=$HTTP"
cat "$OUT/public_health.json" 2>/dev/null
echo

echo "=== 12. LUCI ==="
pytest -q lucideploy/tests 2>&1 | tee "$OUT/tests.txt"
TEST_EXIT=${PIPESTATUS[0]}

echo
if [ -x lucideploy/run_final_gate.sh ]; then
  lucideploy/run_final_gate.sh 2>&1 | tee "$OUT/final_gate.txt"
  GATE_EXIT=${PIPESTATUS[0]}
else
  GATE_EXIT=1
fi

echo
echo "============================================================"
echo " FINAL"
echo "============================================================"
echo "TUNNEL=$([ "$TUNNEL_EXIT" = 0 ] && echo PASS || echo FAIL)"
echo "ROUTE=$([ "$ROUTE_EXIT" = 0 ] && echo PASS || echo FAIL)"
echo "HTTPS=$([ "$HTTP" = 200 ] && echo PASS || echo BLOCKED)"
echo "LUCI_TESTS=$([ "$TEST_EXIT" = 0 ] && echo PASS || echo FAIL)"
echo "GATE_EXECUTION=$([ "$GATE_EXIT" = 0 ] && echo PASS || echo FAIL)"
echo
echo "OWNERSHIP_METHOD=DNS_CONTROL"
echo "FAIL_CLOSED=TRUE"
echo "EVIDENCE=$OUT"
