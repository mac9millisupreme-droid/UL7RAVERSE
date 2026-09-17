#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

DOMAIN="omnilucient.com"
HOST="verify.omnilucient.com"
TUNNEL_ID="a241e27b-336e-44cc-9a52-6487131db63b"
TARGET="${TUNNEL_ID}.cfargotunnel.com"
TXT_HOST="_ul7ra-control.${DOMAIN}"

EVIDENCE="verification_artifacts/elite_forensic/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$EVIDENCE"

FAIL=0
LOCAL=0
AUTH=0
PUBLIC=0
HTTPS=0
TESTS=0
TUNNEL=0
GATES=0

command -v curl >/dev/null || FAIL=1
command -v dig >/dev/null || FAIL=1
command -v git >/dev/null || FAIL=1

{
  echo "TIMESTAMP_UTC=$(date -u +%FT%TZ)"
  echo "PWD=$(pwd)"
  echo "ARCH=$(uname -m)"
  echo "OS=$(uname -o 2>/dev/null || uname -s)"
  echo "KERNEL=$(uname -r)"
  echo "BASH=${BASH_VERSION}"
  echo "DOMAIN=$DOMAIN"
  echo "HOST=$HOST"
  echo "TUNNEL_ID=$TUNNEL_ID"
  echo "TARGET=$TARGET"
} | tee "$EVIDENCE/ENVIRONMENT.txt"

git rev-parse HEAD > "$EVIDENCE/GIT_HEAD.txt" 2>/dev/null || true
git status --short > "$EVIDENCE/GIT_STATUS.txt" 2>/dev/null || true

if [ "$FAIL" -eq 1 ]; then
  echo "DEPENDENCIES_OK=0"
  echo "FINAL_DECISION=BLOCKED"
  echo "EVIDENCE_PATH=$EVIDENCE"
  exit 1
fi

echo "=== LOCAL SERVICES ==="

if curl -fsS \
  --connect-timeout 3 \
  --max-time 5 \
  http://127.0.0.1:8787/health \
  > "$EVIDENCE/UL7RA_LOCAL_HEALTH.txt" 2>&1
then
  LOCAL=1
fi

echo "UL7RA_LOCAL_HEALTH=$LOCAL"

if curl -fsS \
  --connect-timeout 3 \
  --max-time 5 \
  http://127.0.0.1:8899/ \
  > "$EVIDENCE/OMNIPULSE_LOCAL.txt" 2>&1
then
  OMNIPULSE=1
else
  OMNIPULSE=0
fi

echo "OMNIPULSE_LOCAL=$OMNIPULSE"

echo "=== AUTHORITATIVE NAMESERVERS ==="

dig +short NS "$DOMAIN" > "$EVIDENCE/PARENT_NS.txt"

NS1="$(sed -n '1p' "$EVIDENCE/PARENT_NS.txt" | sed 's/\.$//')"
NS2="$(sed -n '2p' "$EVIDENCE/PARENT_NS.txt" | sed 's/\.$//')"

echo "NS1=$NS1"
echo "NS2=$NS2"

if [ -n "$NS1" ] && [ -n "$NS2" ]; then
  dig NS "$DOMAIN" @"$NS1" > "$EVIDENCE/SOA_NS1.txt" 2>&1 || true
  dig NS "$DOMAIN" @"$NS2" > "$EVIDENCE/SOA_NS2.txt" 2>&1 || true
fi

echo "=== AUTHORITATIVE CNAME ==="

if [ -n "$NS1" ] && [ -n "$NS2" ]; then
  dig +short CNAME "$HOST" @"$NS1" \
    | sed 's/\.$//' > "$EVIDENCE/AUTH_CNAME_NS1.txt"

  dig +short CNAME "$HOST" @"$NS2" \
    | sed 's/\.$//' > "$EVIDENCE/AUTH_CNAME_NS2.txt"

  A1="$(cat "$EVIDENCE/AUTH_CNAME_NS1.txt")"
  A2="$(cat "$EVIDENCE/AUTH_CNAME_NS2.txt")"

  echo "AUTH_NS1_CNAME=$A1"
  echo "AUTH_NS2_CNAME=$A2"

  if [ "$A1" = "$TARGET" ] && [ "$A2" = "$TARGET" ]; then
    AUTH=1
  fi
fi

echo "AUTHORITATIVE_DNS_OK=$AUTH"

echo "=== PUBLIC DNS ==="

dig +short CNAME "$HOST" @1.1.1.1 \
  | sed 's/\.$//' > "$EVIDENCE/PUBLIC_CNAME_1.txt"

dig +short CNAME "$HOST" @8.8.8.8 \
  | sed 's/\.$//' > "$EVIDENCE/PUBLIC_CNAME_2.txt"

P1="$(cat "$EVIDENCE/PUBLIC_CNAME_1.txt")"
P2="$(cat "$EVIDENCE/PUBLIC_CNAME_2.txt")"

echo "PUBLIC_1_CNAME=$P1"
echo "PUBLIC_2_CNAME=$P2"

if [ "$P1" = "$TARGET" ] && [ "$P2" = "$TARGET" ]; then
  PUBLIC=1
fi

echo "PUBLIC_DNS_OK=$PUBLIC"

echo "=== CONTROL TXT ==="

if [ -n "$NS1" ] && [ -n "$NS2" ]; then
  dig +short TXT "$TXT_HOST" @"$NS1" \
    > "$EVIDENCE/AUTH_TXT_NS1.txt" 2>&1 || true

  dig +short TXT "$TXT_HOST" @"$NS2" \
    > "$EVIDENCE/AUTH_TXT_NS2.txt" 2>&1 || true
fi

dig +short TXT "$TXT_HOST" @1.1.1.1 \
  > "$EVIDENCE/PUBLIC_TXT_1.txt" 2>&1 || true

dig +short TXT "$TXT_HOST" @8.8.8.8 \
  > "$EVIDENCE/PUBLIC_TXT_2.txt" 2>&1 || true

echo "AUTH_TXT_NS1=$(cat "$EVIDENCE/AUTH_TXT_NS1.txt" 2>/dev/null || true)"
echo "AUTH_TXT_NS2=$(cat "$EVIDENCE/AUTH_TXT_NS2.txt" 2>/dev/null || true)"
echo "PUBLIC_TXT_1=$(cat "$EVIDENCE/PUBLIC_TXT_1.txt" 2>/dev/null || true)"
echo "PUBLIC_TXT_2=$(cat "$EVIDENCE/PUBLIC_TXT_2.txt" 2>/dev/null || true)"

echo "=== HTTPS ==="

HTTP_CODE="$(
  curl -kLsS \
    --connect-timeout 10 \
    --max-time 20 \
    -o "$EVIDENCE/PUBLIC_HEALTH_RESPONSE.txt" \
    -w '%{http_code}' \
    "https://${HOST}/health" \
    2>/dev/null || true
)"

echo "PUBLIC_HTTPS_STATUS=$HTTP_CODE"

if [ "$HTTP_CODE" = "200" ]; then
  HTTPS=1
fi

echo "PUBLIC_HTTPS_OK=$HTTPS"

echo "=== CLOUDFLARE TUNNEL ==="

if command -v cloudflared >/dev/null; then
  cloudflared tunnel list \
    > "$EVIDENCE/CLOUDFLARED_TUNNEL_LIST.txt" 2>&1 || true

  cloudflared tunnel info "$TUNNEL_ID" \
    > "$EVIDENCE/CLOUDFLARED_TUNNEL_INFO.txt" 2>&1 || true

  if grep -q "$TUNNEL_ID" "$EVIDENCE/CLOUDFLARED_TUNNEL_LIST.txt" \
    || grep -q "$TUNNEL_ID" "$EVIDENCE/CLOUDFLARED_TUNNEL_INFO.txt"
  then
    TUNNEL=1
  fi
fi

echo "CLOUDFLARE_TUNNEL_PRESENT=$TUNNEL"

echo "=== PROJECT TESTS ==="

if command -v pytest >/dev/null && [ -d lucideploy/tests ]; then
  if pytest -q lucideploy/tests \
    > "$EVIDENCE/LUCIDEPLOY_TESTS.txt" 2>&1
  then
    TESTS=1
  fi
fi

echo "LUCIDEPLOY_TESTS_OK=$TESTS"

echo "=== AUTHORITATIVE LUCI GATE ==="

LUCI_GATE=0

if [ -f lucideploy/run_final_gate.sh ]; then
  if bash lucideploy/run_final_gate.sh \
    > "$EVIDENCE/LUCI_FINAL_GATE.txt" 2>&1
  then
    if grep -q 'FINAL=PASS' "$EVIDENCE/LUCI_FINAL_GATE.txt" \
      && ! grep -q 'FINAL=BLOCKED' "$EVIDENCE/LUCI_FINAL_GATE.txt"
    then
      LUCI_GATE=1
    fi
  fi
fi

echo "LUCI_FINAL_GATE_PASS=$LUCI_GATE"

echo "=== FINAL FAIL-CLOSED EVALUATION ==="

if [ "$LOCAL" -eq 1 ] &&
   [ "$AUTH" -eq 1 ] &&
   [ "$PUBLIC" -eq 1 ] &&
   [ "$HTTPS" -eq 1 ] &&
   [ "$TESTS" -eq 1 ] &&
   [ "$LUCI_GATE" -eq 1 ]
then
  GATES=1
fi

PAYMENT_VERIFIED=0
VERIFIED_REVENUE_CAD=0
PRODUCTION_UNLOCK=0
CANONICAL_PROMOTION=0
PUBLIC_EXPOSURE_AUTHORIZED=0

if [ "$GATES" -eq 1 ]; then
  PRODUCTION_UNLOCK=1
  CANONICAL_PROMOTION=1
  PUBLIC_EXPOSURE_AUTHORIZED=1
fi

echo "GATES_OK=$GATES"
echo "LOCAL_OK=$LOCAL"
echo "DNS_OK=$PUBLIC"
echo "AUTHORITATIVE_DNS_OK=$AUTH"
echo "PUBLIC_DNS_OK=$PUBLIC"
echo "HTTPS_OK=$HTTPS"
echo "APPLICATION_OK=$HTTPS"
echo "TESTS_OK=$TESTS"
echo "PAYMENT_VERIFIED=$PAYMENT_VERIFIED"
echo "VERIFIED_REVENUE_CAD=$VERIFIED_REVENUE_CAD"
echo "PRODUCTION_UNLOCK=$PRODUCTION_UNLOCK"
echo "CANONICAL_PROMOTION=$CANONICAL_PROMOTION"
echo "PUBLIC_EXPOSURE_AUTHORIZED=$PUBLIC_EXPOSURE_AUTHORIZED"

if [ "$GATES" -eq 1 ]; then
  echo "FINAL_DECISION=PASS"
else
  echo "FINAL_DECISION=BLOCKED"
fi

echo "EVIDENCE_PATH=$EVIDENCE"

cat > "$EVIDENCE/FINAL_STATUS.txt" <<EOF
GATES_OK=$GATES
LOCAL_OK=$LOCAL
DNS_OK=$PUBLIC
AUTHORITATIVE_DNS_OK=$AUTH
PUBLIC_DNS_OK=$PUBLIC
HTTPS_OK=$HTTPS
APPLICATION_OK=$HTTPS
TESTS_OK=$TESTS
PAYMENT_VERIFIED=$PAYMENT_VERIFIED
VERIFIED_REVENUE_CAD=$VERIFIED_REVENUE_CAD
PRODUCTION_UNLOCK=$PRODUCTION_UNLOCK
CANONICAL_PROMOTION=$CANONICAL_PROMOTION
PUBLIC_EXPOSURE_AUTHORIZED=$PUBLIC_EXPOSURE_AUTHORIZED
FINAL_DECISION=$([ "$GATES" -eq 1 ] && echo PASS || echo BLOCKED)
EVIDENCE_PATH=$EVIDENCE
EOF

exit "$([ "$GATES" -eq 1 ] && echo 0 || echo 1)"
