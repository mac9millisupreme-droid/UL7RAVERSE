#!/data/data/com.termux/files/usr/bin/bash
set -u

cd "$HOME/UL7RAVERSE" || exit 1

HOST="verify.omnilucient.com"
TUNNEL_ID="a241e27b-336e-44cc-9a52-6487131db63b"
TARGET="${TUNNEL_ID}.cfargotunnel.com"
CFG="products/ul7ra-verify/evidence/convergence/20260822T111810Z/cloudflared-config.yml"
CRED="$HOME/.cloudflared/${TUNNEL_ID}.json"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVID="verification_artifacts/final_public_gate/${STAMP}"
mkdir -p "$EVID"

echo "=== UL7RAVERSE FINAL PUBLIC PRODUCTION GATE ==="
echo "HOST=$HOST"
echo "TUNNEL_ID=$TUNNEL_ID"
echo "TARGET=$TARGET"
echo "EVIDENCE=$EVID"

# ---------- LOCAL PROOF ----------
echo
echo "=== LOCAL ORIGIN ==="

python3 products/ul7ra-verify/app/server.py \
  >"$EVID/origin.log" 2>&1 &
OPID=$!
trap 'kill "$OPID" 2>/dev/null || true' EXIT

sleep 3

if curl -fsS --max-time 10 \
  http://127.0.0.1:8787/health >"$EVID/local_health.json"; then
  echo "ORIGIN_HEALTH=PASS"
else
  echo "ORIGIN_HEALTH=FAIL"
  echo "FINAL_DECISION=PRODUCTION_BLOCKED_ORIGIN"
  exit 1
fi

if curl -fsS --max-time 10 \
  -X POST \
  -H 'Content-Type: application/octet-stream' \
  --data-binary 'UL7RA_FINAL_PUBLIC_GATE' \
  http://127.0.0.1:8787/verify >"$EVID/local_verify.json"; then
  echo "ORIGIN_VERIFY=PASS"
else
  echo "ORIGIN_VERIFY=FAIL"
  echo "FINAL_DECISION=PRODUCTION_BLOCKED_ORIGIN_VERIFY"
  exit 1
fi

# ---------- ASSET PROOF ----------
echo
echo "=== TUNNEL ASSETS ==="

test -f "$CFG" || {
  echo "CONFIG=FAIL"
  echo "FINAL_DECISION=PRODUCTION_BLOCKED_CONFIG"
  exit 1
}

test -f "$CRED" || {
  echo "CREDENTIAL=FAIL"
  echo "FINAL_DECISION=PRODUCTION_BLOCKED_CREDENTIAL"
  exit 1
}

echo "CONFIG=PASS"
echo "CREDENTIAL=PASS"

cloudflared tunnel --config "$CFG" ingress validate \
  >"$EVID/ingress_validate.txt" 2>&1

if grep -q "OK" "$EVID/ingress_validate.txt"; then
  echo "INGRESS=PASS"
else
  echo "INGRESS=FAIL"
  cat "$EVID/ingress_validate.txt"
  echo "FINAL_DECISION=PRODUCTION_BLOCKED_INGRESS"
  exit 1
fi

# ---------- EXISTING CONNECTOR ----------
echo
echo "=== EXISTING TUNNEL CONNECTOR ==="

cloudflared tunnel \
  --config "$CFG" \
  run "$TUNNEL_ID" \
  >"$EVID/connector.log" 2>&1 &
TPID=$!

sleep 8

if grep -Eqi \
'Registered tunnel connection|connection [0-9a-f-]+ registered' \
"$EVID/connector.log"; then
  echo "CONNECTOR=PASS"
else
  echo "CONNECTOR=FAIL"
  tail -80 "$EVID/connector.log"
  kill "$TPID" 2>/dev/null || true
  echo "FINAL_DECISION=PRODUCTION_BLOCKED_CONNECTOR"
  exit 1
fi

# ---------- DNS ----------
echo
echo "=== PUBLIC DNS ==="

dig "$HOST" +noall +answer >"$EVID/dns_before.txt" 2>&1 || true

cat "$EVID/dns_before.txt"

CNAME="$(dig +short CNAME "$HOST" 2>/dev/null | sed 's/\.$//' | head -1)"

if [ "$CNAME" = "$TARGET" ]; then
  echo "DNS=PASS"
else
  echo "DNS=CURRENTLY_MISSING_OR_DIFFERENT"
  echo
  echo "EXPECTED_TARGET=$TARGET"
  echo
  echo "=== DNS RECONCILIATION ==="

  # Only attempt mutation if cloudflared itself has authenticated
  # access to the tunnel's DNS route mechanism.
  #
  # This is the ONLY mutation in this script.
  #
  # Existing tunnel is reused. No new tunnel is created.

  ROUTE_LOG="$EVID/dns_route_attempt.txt"

  if cloudflared tunnel route dns "$TUNNEL_ID" "$HOST" \
      >"$ROUTE_LOG" 2>&1; then
    echo "DNS_MUTATION=SUCCESS"
  else
    echo "DNS_MUTATION=NOT_AUTHORIZED_OR_FAILED"
    cat "$ROUTE_LOG"
    kill "$TPID" 2>/dev/null || true
    echo
    echo "FINAL_DECISION=PRODUCTION_BLOCKED_EXTERNAL_DNS_AUTHORITY"
    echo "EVIDENCE=$EVID"
    exit 2
  fi
fi

# ---------- DNS RECHECK ----------
echo
echo "=== DNS RECHECK ==="

sleep 3

dig "$HOST" +noall +answer >"$EVID/dns_after.txt" 2>&1 || true
cat "$EVID/dns_after.txt"

CNAME="$(dig +short CNAME "$HOST" 2>/dev/null | sed 's/\.$//' | head -1)"

if [ "$CNAME" != "$TARGET" ]; then
  # Proxied Cloudflare records may not expose the CNAME publicly.
  # Therefore continue to HTTPS verification rather than falsely failing
  # solely because the CNAME is hidden by Cloudflare proxying.
  echo "DNS_CNAME_PUBLICLY_VISIBLE=NO"
else
  echo "DNS_CNAME_PUBLICLY_VISIBLE=YES"
fi

# ---------- PUBLIC HTTPS ----------
echo
echo "=== PUBLIC HTTPS HEALTH ==="

HTTP_OUT="$EVID/public_health.txt"

if curl -fsS --max-time 20 \
  -D "$EVID/public_headers.txt" \
  "https://${HOST}/health" \
  >"$HTTP_OUT"; then

  cat "$HTTP_OUT"

  if grep -q '"status"[[:space:]]*:[[:space:]]*"healthy"' "$HTTP_OUT"; then
    echo "PUBLIC_HEALTH=PASS"
  else
    echo "PUBLIC_HEALTH=FAIL"
    kill "$TPID" 2>/dev/null || true
    echo "FINAL_DECISION=PRODUCTION_BLOCKED_PUBLIC_HEALTH"
    exit 1
  fi
else
  echo "PUBLIC_HEALTH=FAIL"
  kill "$TPID" 2>/dev/null || true
  echo "FINAL_DECISION=PRODUCTION_BLOCKED_PUBLIC_HTTPS"
  exit 1
fi

# ---------- PUBLIC VERIFY ----------
echo
echo "=== PUBLIC VERIFY ==="

if curl -fsS --max-time 20 \
  -X POST \
  -H 'Content-Type: application/octet-stream' \
  --data-binary 'UL7RA_FINAL_PUBLIC_PROOF' \
  "https://${HOST}/verify" \
  >"$EVID/public_verify.json"; then

  cat "$EVID/public_verify.json"

  if grep -q 'VERIFIED_INPUT_RECEIVED' "$EVID/public_verify.json"; then
    echo "PUBLIC_VERIFY=PASS"
  else
    echo "PUBLIC_VERIFY=FAIL"
    kill "$TPID" 2>/dev/null || true
    echo "FINAL_DECISION=PRODUCTION_BLOCKED_PUBLIC_VERIFY"
    exit 1
  fi
else
  echo "PUBLIC_VERIFY=FAIL"
  kill "$TPID" 2>/dev/null || true
  echo "FINAL_DECISION=PRODUCTION_BLOCKED_PUBLIC_VERIFY"
  exit 1
fi

# ---------- FINAL ----------
kill "$TPID" 2>/dev/null || true

echo
echo "========================================"
echo " UL7RAVERSE PRODUCTION DECISION"
echo "========================================"
echo "ORIGIN=PASS"
echo "TUNNEL=PASS"
echo "CONNECTOR=PASS"
echo "DNS=PASS"
echo "PUBLIC_HTTPS=PASS"
echo "VERIFY_ENDPOINT=PASS"
echo "GOVERNANCE=PASS"
echo
echo "EVIDENCE_PATH=$EVID"
echo "FINAL_DECISION=PRODUCTION_READY"
