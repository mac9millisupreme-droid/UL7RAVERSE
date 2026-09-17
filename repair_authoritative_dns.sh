#!/data/data/com.termux/files/usr/bin/bash
set -u

cd ~/UL7RAVERSE || exit 1

DOMAIN="omnilucient.com"
HOST="verify.${DOMAIN}"
TXT_HOST="_ul7ra-control.${DOMAIN}"
TUNNEL_ID="a241e27b-336e-44cc-9a52-6487131db63b"
CNAME_TARGET="${TUNNEL_ID}.cfargotunnel.com."
TXT_VALUE="UL7RA-CONTROL-20260912T000358Z"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE="verification_artifacts/dns_repair/${STAMP}"
mkdir -p "$EVIDENCE"

echo "=== UL7RA AUTHORITATIVE DNS REPAIR ==="
echo "DOMAIN=$DOMAIN"
echo "HOST=$HOST"
echo "TARGET=$CNAME_TARGET"
echo "TXT_HOST=$TXT_HOST"
echo "EVIDENCE=$EVIDENCE"
echo

# ------------------------------------------------------------
# 1. Locate credentials WITHOUT PRINTING THEM
# ------------------------------------------------------------

TOKEN="${CLOUDFLARE_API_TOKEN:-${CF_API_TOKEN:-}}"

if [ -z "$TOKEN" ]; then
    echo "DNS_REPAIR=CREDENTIALS_REQUIRED"
    echo "DNS_CONTROL=BLOCKED"
    echo "PRODUCTION=BLOCKED"
    echo "PROMOTION=BLOCKED"
    echo "FINAL_DECISION=BLOCKED"
    echo
    echo "Required authoritative records:"
    echo
    echo "verify.omnilucient.com CNAME ${CNAME_TARGET}"
    echo "_ul7ra-control.omnilucient.com TXT \"${TXT_VALUE}\""
    echo
    echo "No Cloudflare API token was detected."
    echo "Configure CLOUDFLARE_API_TOKEN locally and rerun."
    exit 20
fi

# ------------------------------------------------------------
# 2. Cloudflare API helper
# ------------------------------------------------------------

cf_api() {
    curl -fsS \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      "$@"
}

echo "CREDENTIAL_PRESENT=1"

# ------------------------------------------------------------
# 3. Find authoritative zone
# ------------------------------------------------------------

ZONE_JSON="$(cf_api "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}&status=active" \
    2>"$EVIDENCE/api_zone_error.txt" || true)"

echo "$ZONE_JSON" > "$EVIDENCE/zone_response.json"

ZONE_ID="$(printf '%s' "$ZONE_JSON" | python -c '
import json,sys
try:
    j=json.load(sys.stdin)
    r=j.get("result",[])
    print(r[0]["id"] if r else "")
except Exception:
    print("")
')"

if [ -z "$ZONE_ID" ]; then
    echo "ZONE_LOOKUP=FAIL"
    echo "DNS_CONTROL=BLOCKED"
    echo "FINAL_DECISION=BLOCKED"
    exit 21
fi

echo "ZONE_LOOKUP=PASS"

# ------------------------------------------------------------
# 4. Inspect existing records
# ------------------------------------------------------------

CNAME_JSON="$(cf_api \
 "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=CNAME&name=${HOST}" \
 2>"$EVIDENCE/cname_lookup_error.txt" || true)"

TXT_JSON="$(cf_api \
 "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=TXT&name=${TXT_HOST}" \
 2>"$EVIDENCE/txt_lookup_error.txt" || true)"

echo "$CNAME_JSON" > "$EVIDENCE/cname_before.json"
echo "$TXT_JSON" > "$EVIDENCE/txt_before.json"

CNAME_ID="$(printf '%s' "$CNAME_JSON" | python -c '
import json,sys
try:
 j=json.load(sys.stdin); r=j.get("result",[])
 print(r[0]["id"] if r else "")
except: print("")
')"

TXT_ID="$(printf '%s' "$TXT_JSON" | python -c '
import json,sys
try:
 j=json.load(sys.stdin); r=j.get("result",[])
 print(r[0]["id"] if r else "")
except: print("")
')"

# ------------------------------------------------------------
# 5. Repair CNAME
# ------------------------------------------------------------

CNAME_BODY="$(python - <<PY
import json
print(json.dumps({
  "type":"CNAME",
  "name":"${HOST}",
  "content":"${CNAME_TARGET}",
  "ttl":1,
  "proxied":True
}))
PY
)"

if [ -n "$CNAME_ID" ]; then
    CNAME_RESULT="$(cf_api -X PUT \
      "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${CNAME_ID}" \
      --data "$CNAME_BODY" \
      2>"$EVIDENCE/cname_write_error.txt" || true)"
    CNAME_ACTION="UPDATED"
else
    CNAME_RESULT="$(cf_api -X POST \
      "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
      --data "$CNAME_BODY" \
      2>"$EVIDENCE/cname_write_error.txt" || true)"
    CNAME_ACTION="CREATED"
fi

echo "$CNAME_RESULT" > "$EVIDENCE/cname_write.json"

CNAME_OK="$(printf '%s' "$CNAME_RESULT" | python -c '
import json,sys
try: print("1" if json.load(sys.stdin).get("success") else "0")
except: print("0")
')"

echo "CNAME_${CNAME_ACTION}=${CNAME_OK}"

# ------------------------------------------------------------
# 6. Repair TXT ownership/control record
# ------------------------------------------------------------

TXT_BODY="$(python - <<PY
import json
print(json.dumps({
  "type":"TXT",
  "name":"${TXT_HOST}",
  "content":"${TXT_VALUE}",
  "ttl":60
}))
PY
)"

if [ -n "$TXT_ID" ]; then
    TXT_RESULT="$(cf_api -X PUT \
      "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${TXT_ID}" \
      --data "$TXT_BODY" \
      2>"$EVIDENCE/txt_write_error.txt" || true)"
    TXT_ACTION="UPDATED"
else
    TXT_RESULT="$(cf_api -X POST \
      "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
      --data "$TXT_BODY" \
      2>"$EVIDENCE/txt_write_error.txt" || true)"
    TXT_ACTION="CREATED"
fi

echo "$TXT_RESULT" > "$EVIDENCE/txt_write.json"

TXT_OK="$(printf '%s' "$TXT_RESULT" | python -c '
import json,sys
try: print("1" if json.load(sys.stdin).get("success") else "0")
except: print("0")
')"

echo "TXT_${TXT_ACTION}=${TXT_OK}"

# ------------------------------------------------------------
# 7. Discover authoritative nameservers
# ------------------------------------------------------------

NS1="$(dig +short NS "$DOMAIN" | sed -n '1p')"
NS2="$(dig +short NS "$DOMAIN" | sed -n '2p')"

echo "NS1=$NS1"
echo "NS2=$NS2"

AUTH_CNAME_MATCHES=0
AUTH_TXT_MATCHES=0

for NS in "$NS1" "$NS2"; do
    [ -z "$NS" ] && continue

    C="$(dig +short @"$NS" "$HOST" CNAME | sed 's/\.$//' | tr '[:upper:]' '[:lower:]')"
    T="$(dig +short @"$NS" "$TXT_HOST" TXT | tr -d '"' | tr '[:upper:]' '[:lower:]')"

    echo "$NS CNAME=$C"
    echo "$NS TXT=$T"

    if [ "$C" = "${CNAME_TARGET%.}" ]; then
        AUTH_CNAME_MATCHES=$((AUTH_CNAME_MATCHES+1))
    fi

    if [ "$T" = "${TXT_VALUE,,}" ]; then
        AUTH_TXT_MATCHES=$((AUTH_TXT_MATCHES+1))
    fi
done

echo "AUTHORITATIVE_CNAME_MATCHES=$AUTH_CNAME_MATCHES"
echo "AUTHORITATIVE_TXT_MATCHES=$AUTH_TXT_MATCHES"

# ------------------------------------------------------------
# 8. Public resolver verification
# ------------------------------------------------------------

PUBLIC_CNAME_MATCHES=0
PUBLIC_TXT_MATCHES=0

for RESOLVER in 1.1.1.1 8.8.8.8; do
    C="$(dig +short @"$RESOLVER" "$HOST" CNAME | sed 's/\.$//' | tr '[:upper:]' '[:lower:]')"
    T="$(dig +short @"$RESOLVER" "$TXT_HOST" TXT | tr -d '"' | tr '[:upper:]' '[:lower:]')"

    echo "$RESOLVER CNAME=$C"
    echo "$RESOLVER TXT=$T"

    if [ "$C" = "${CNAME_TARGET%.}" ]; then
        PUBLIC_CNAME_MATCHES=$((PUBLIC_CNAME_MATCHES+1))
    fi

    if [ "$T" = "${TXT_VALUE,,}" ]; then
        PUBLIC_TXT_MATCHES=$((PUBLIC_TXT_MATCHES+1))
    fi
done

echo "PUBLIC_CNAME_MATCHES=$PUBLIC_CNAME_MATCHES"
echo "PUBLIC_TXT_MATCHES=$PUBLIC_TXT_MATCHES"

# ------------------------------------------------------------
# 9. Public HTTPS verification
# ------------------------------------------------------------

HTTP_STATUS="$(curl -kLsS -o "$EVIDENCE/https_body.txt" \
    -w '%{http_code}' \
    --connect-timeout 10 \
    --max-time 20 \
    "https://${HOST}/health" 2>"$EVIDENCE/https_error.txt" || true)"

echo "PUBLIC_HTTPS=$HTTP_STATUS"

# ------------------------------------------------------------
# 10. Final DNS truth
# ------------------------------------------------------------

if [ "$CNAME_OK" = "1" ] &&
   [ "$TXT_OK" = "1" ] &&
   [ "$AUTH_CNAME_MATCHES" = "2" ] &&
   [ "$AUTH_TXT_MATCHES" = "2" ] &&
   [ "$PUBLIC_CNAME_MATCHES" = "2" ] &&
   [ "$PUBLIC_TXT_MATCHES" = "2" ] &&
   [ "$HTTP_STATUS" = "200" ]; then

    DNS_CONTROL="PROVEN"
    PUBLIC_DNS="PASS"
    PUBLIC_VERIFY="PASS"
else
    DNS_CONTROL="BLOCKED"
    PUBLIC_DNS="BLOCKED"
    PUBLIC_VERIFY="BLOCKED"
fi

echo
echo "=== DNS TRUTH ==="
echo "DNS_CONTROL=$DNS_CONTROL"
echo "PUBLIC_DNS=$PUBLIC_DNS"
echo "PUBLIC_VERIFY=$PUBLIC_VERIFY"

# ------------------------------------------------------------
# 11. Run LUCI only after DNS mutation/verification
# ------------------------------------------------------------

LUCI_RESULT="NOT_RUN"

if [ "$PUBLIC_VERIFY" = "PASS" ]; then
    if [ -x lucideploy/run_final_gate.sh ]; then
        if lucideploy/run_final_gate.sh > "$EVIDENCE/luci_final_gate.txt" 2>&1; then
            LUCI_RESULT="PASS"
        else
            LUCI_RESULT="FAIL"
        fi
    else
        LUCI_RESULT="MISSING"
    fi
else
    LUCI_RESULT="BLOCKED_DNS"
fi

echo "LUCI_RESULT=$LUCI_RESULT"

# ------------------------------------------------------------
# 12. Absolute fail-closed final decision
# ------------------------------------------------------------

if [ "$DNS_CONTROL" = "PROVEN" ] &&
   [ "$PUBLIC_DNS" = "PASS" ] &&
   [ "$PUBLIC_VERIFY" = "PASS" ] &&
   [ "$LUCI_RESULT" = "PASS" ]; then

    PRODUCTION="UNBLOCKED"
    PROMOTION="AUTHORIZED"
    FINAL_DECISION="PASS"
else
    PRODUCTION="BLOCKED"
    PROMOTION="BLOCKED"
    FINAL_DECISION="BLOCKED"
fi

cat > "$EVIDENCE/FINAL_STATUS.txt" <<EOF
UL7RA AUTHORITATIVE DNS REPAIR

DOMAIN=$DOMAIN
CNAME_TARGET=$CNAME_TARGET
TXT_VALUE=$TXT_VALUE

AUTHORITATIVE_CNAME_MATCHES=$AUTH_CNAME_MATCHES
AUTHORITATIVE_TXT_MATCHES=$AUTH_TXT_MATCHES
PUBLIC_CNAME_MATCHES=$PUBLIC_CNAME_MATCHES
PUBLIC_TXT_MATCHES=$PUBLIC_TXT_MATCHES

PUBLIC_HTTPS=$HTTP_STATUS

DNS_CONTROL=$DNS_CONTROL
PUBLIC_DNS=$PUBLIC_DNS
PUBLIC_VERIFY=$PUBLIC_VERIFY
LUCI_RESULT=$LUCI_RESULT

PRODUCTION=$PRODUCTION
PROMOTION=$PROMOTION
FINAL_DECISION=$FINAL_DECISION
FAIL_CLOSED=TRUE
EOF

cat "$EVIDENCE/FINAL_STATUS.txt"

echo
echo "EVIDENCE_PATH=$EVIDENCE"

[ "$FINAL_DECISION" = "PASS" ]
