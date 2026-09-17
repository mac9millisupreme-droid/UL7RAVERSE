#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

DOMAIN="omnilucient.com"
HOST="verify.omnilucient.com"
TUNNEL_ID="a241e27b-336e-44cc-9a52-6487131db63b"
TARGET="${TUNNEL_ID}.cfargotunnel.com"
TXT_HOST="_ul7ra-control.${DOMAIN}"
TXT_VALUE="UL7RA-CONTROL-20260912T000358Z"

EVIDENCE="$PWD/verification_artifacts/dns_repair_execute/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$EVIDENCE"

need() { command -v "$1" >/dev/null 2>&1 || { echo "MISSING_DEPENDENCY=$1"; echo "FINAL_DECISION=BLOCKED"; exit 1; }; }
need curl
need dig
need python
need bash

echo "TIMESTAMP_UTC=$(date -u +%FT%TZ)"
echo "EVIDENCE_PATH=$EVIDENCE"
echo "DOMAIN=$DOMAIN"
echo "HOST=$HOST"
echo "TUNNEL_ID=$TUNNEL_ID"
echo "TARGET=$TARGET"

printf "Cloudflare API Token (hidden input): "
IFS= read -r -s CLOUDFLARE_API_TOKEN
echo
[ -n "$CLOUDFLARE_API_TOKEN" ] || { echo "TOKEN_PRESENT=0"; echo "FINAL_DECISION=BLOCKED"; exit 1; }

AUTH=(-H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json")

ZONE_JSON="$(curl -fsS "${AUTH[@]}" \
  "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN&status=active" \
  2>"$EVIDENCE/zone_error.txt")" || {
    unset CLOUDFLARE_API_TOKEN
    echo "CLOUDFLARE_ZONE_LOOKUP=FAIL"
    echo "FINAL_DECISION=BLOCKED"
    exit 1
}

ZONE_ID="$(printf '%s' "$ZONE_JSON" | python -c '
import sys,json
d=json.load(sys.stdin)
r=d.get("result",[])
print(r[0]["id"] if r else "")
')"

[ -n "$ZONE_ID" ] || {
    unset CLOUDFLARE_API_TOKEN
    echo "CLOUDFLARE_ZONE=NOT_FOUND"
    echo "FINAL_DECISION=BLOCKED"
    exit 1
}

echo "CLOUDFLARE_ZONE=FOUND"

RECORDS="$(curl -fsS "${AUTH[@]}" \
  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?per_page=100" \
  2>"$EVIDENCE/records_error.txt")" || {
    unset CLOUDFLARE_API_TOKEN
    echo "DNS_RECORD_READ=FAIL"
    echo "FINAL_DECISION=BLOCKED"
    exit 1
}

printf '%s' "$RECORDS" > "$EVIDENCE/records_before.json"

CNAME_ID="$(printf '%s' "$RECORDS" | python -c '
import sys,json
d=json.load(sys.stdin)
for r in d.get("result",[]):
    if r.get("type")=="CNAME" and r.get("name")==sys.argv[1]:
        print(r["id"]); break
' "$HOST")"

TXT_ID="$(printf '%s' "$RECORDS" | python -c '
import sys,json
d=json.load(sys.stdin)
for r in d.get("result",[]):
    if r.get("type")=="TXT" and r.get("name")==sys.argv[1]:
        print(r["id"]); break
' "$TXT_HOST")"

CNAME_BODY="$(python -c 'import json,sys; print(json.dumps({"type":"CNAME","name":sys.argv[1],"content":sys.argv[2],"ttl":1,"proxied":False}))' "$HOST" "$TARGET")"
TXT_BODY="$(python -c 'import json,sys; print(json.dumps({"type":"TXT","name":sys.argv[1],"content":sys.argv[2],"ttl":1}))' "$TXT_HOST" "$TXT_VALUE")"

echo "=== CNAME MUTATION ==="

if [ -n "$CNAME_ID" ]; then
  curl -fsS "${AUTH[@]}" -X PUT \
    "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$CNAME_ID" \
    --data "$CNAME_BODY" > "$EVIDENCE/cname_mutation.json"
else
  curl -fsS "${AUTH[@]}" -X POST \
    "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
    --data "$CNAME_BODY" > "$EVIDENCE/cname_mutation.json"
fi

grep -q '"success":true' "$EVIDENCE/cname_mutation.json" || {
  unset CLOUDFLARE_API_TOKEN
  echo "CNAME_MUTATION=FAIL"
  echo "FINAL_DECISION=BLOCKED"
  exit 1
}

echo "CNAME_MUTATION=PASS"

echo "=== TXT MUTATION ==="

if [ -n "$TXT_ID" ]; then
  curl -fsS "${AUTH[@]}" -X PUT \
    "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$TXT_ID" \
    --data "$TXT_BODY" > "$EVIDENCE/txt_mutation.json"
else
  curl -fsS "${AUTH[@]}" -X POST \
    "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
    --data "$TXT_BODY" > "$EVIDENCE/txt_mutation.json"
fi

grep -q '"success":true' "$EVIDENCE/txt_mutation.json" || {
  unset CLOUDFLARE_API_TOKEN
  echo "TXT_MUTATION=FAIL"
  echo "FINAL_DECISION=BLOCKED"
  exit 1
}

echo "TXT_MUTATION=PASS"

unset CLOUDFLARE_API_TOKEN

echo "=== AUTHORITATIVE VERIFICATION ==="

NS1="$(dig +short NS "$DOMAIN" | sed -n '1p' | sed 's/\.$//')"
NS2="$(dig +short NS "$DOMAIN" | sed -n '2p' | sed 's/\.$//')"

echo "NS1=$NS1"
echo "NS2=$NS2"

A1="$(dig +short CNAME "$HOST" @"$NS1" | sed 's/\.$//')"
A2="$(dig +short CNAME "$HOST" @"$NS2" | sed 's/\.$//')"

T1="$(dig +short TXT "$TXT_HOST" @"$NS1" || true)"
T2="$(dig +short TXT "$TXT_HOST" @"$NS2" || true)"

echo "AUTH_CNAME_1=$A1"
echo "AUTH_CNAME_2=$A2"
echo "AUTH_TXT_1=$T1"
echo "AUTH_TXT_2=$T2"

AUTH_CNAME=0
AUTH_TXT=0

[ "$A1" = "$TARGET" ] && [ "$A2" = "$TARGET" ] && AUTH_CNAME=1
printf '%s\n%s\n' "$T1" "$T2" | grep -Fq "$TXT_VALUE" && AUTH_TXT=1

echo "AUTHORITATIVE_CNAME_OK=$AUTH_CNAME"
echo "AUTHORITATIVE_TXT_OK=$AUTH_TXT"

echo "=== PUBLIC VERIFICATION ==="

P1="$(dig +short CNAME "$HOST" @1.1.1.1 | sed 's/\.$//')"
P2="$(dig +short CNAME "$HOST" @8.8.8.8 | sed 's/\.$//')"
PT1="$(dig +short TXT "$TXT_HOST" @1.1.1.1 || true)"
PT2="$(dig +short TXT "$TXT_HOST" @8.8.8.8 || true)"

echo "PUBLIC_CNAME_1=$P1"
echo "PUBLIC_CNAME_2=$P2"
echo "PUBLIC_TXT_1=$PT1"
echo "PUBLIC_TXT_2=$PT2"

PUBLIC_CNAME=0
PUBLIC_TXT=0

[ "$P1" = "$TARGET" ] && [ "$P2" = "$TARGET" ] && PUBLIC_CNAME=1
printf '%s\n%s\n' "$PT1" "$PT2" | grep -Fq "$TXT_VALUE" && PUBLIC_TXT=1

echo "PUBLIC_CNAME_OK=$PUBLIC_CNAME"
echo "PUBLIC_TXT_OK=$PUBLIC_TXT"

echo "=== HTTPS ==="

HTTP_CODE="$(curl -kLsS \
  --connect-timeout 10 \
  --max-time 20 \
  -o "$EVIDENCE/health.txt" \
  -w '%{http_code}' \
  "https://$HOST/health" 2>/dev/null || true)"

echo "PUBLIC_HTTPS_STATUS=$HTTP_CODE"

HTTPS=0
[ "$HTTP_CODE" = "200" ] && HTTPS=1
echo "PUBLIC_HTTPS_OK=$HTTPS"

echo "=== FINAL ==="

LOCAL=0
if curl -fsS --connect-timeout 3 --max-time 5 \
  http://127.0.0.1:8787/health \
  > "$EVIDENCE/local_ul7ra_health.txt" 2>&1
then LOCAL=1
fi

TESTS=0
if command -v pytest >/dev/null 2>&1 && [ -d lucideploy/tests ]; then
  pytest -q lucideploy/tests > "$EVIDENCE/tests.txt" 2>&1 && TESTS=1 || true
fi

LUCI=0
if [ -f lucideploy/run_final_gate.sh ]; then
  bash lucideploy/run_final_gate.sh > "$EVIDENCE/luci_final_gate.txt" 2>&1 || true
  grep -q 'FINAL=PASS' "$EVIDENCE/luci_final_gate.txt" &&
  ! grep -q 'FINAL=BLOCKED' "$EVIDENCE/luci_final_gate.txt" &&
  LUCI=1 || true
fi

GATES=0
if [ "$LOCAL" -eq 1 ] &&
   [ "$AUTH_CNAME" -eq 1 ] &&
   [ "$AUTH_TXT" -eq 1 ] &&
   [ "$PUBLIC_CNAME" -eq 1 ] &&
   [ "$PUBLIC_TXT" -eq 1 ] &&
   [ "$HTTPS" -eq 1 ] &&
   [ "$TESTS" -eq 1 ] &&
   [ "$LUCI" -eq 1 ]; then
  GATES=1
fi

PAYMENT_VERIFIED=0
VERIFIED_REVENUE_CAD=0
PRODUCTION_UNLOCK=0
CANONICAL_PROMOTION=0
PUBLIC_EXPOSURE_AUTHORIZED=0

[ "$GATES" -eq 1 ] && {
  PRODUCTION_UNLOCK=1
  CANONICAL_PROMOTION=1
  PUBLIC_EXPOSURE_AUTHORIZED=1
}

echo "GATES_OK=$GATES"
echo "LOCAL_OK=$LOCAL"
echo "DNS_OK=$PUBLIC_CNAME"
echo "AUTHORITATIVE_DNS_OK=$AUTH_CNAME"
echo "PUBLIC_DNS_OK=$PUBLIC_CNAME"
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
  RC=0
else
  echo "FINAL_DECISION=BLOCKED"
  RC=1
fi

echo "EVIDENCE_PATH=$EVIDENCE"

cat > "$EVIDENCE/FINAL_STATUS.txt" <<EOF
GATES_OK=$GATES
LOCAL_OK=$LOCAL
DNS_OK=$PUBLIC_CNAME
AUTHORITATIVE_DNS_OK=$AUTH_CNAME
PUBLIC_DNS_OK=$PUBLIC_CNAME
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

exit "$RC"
