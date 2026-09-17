#!/data/data/com.termux/files/usr/bin/bash
set -u

cd "$HOME/UL7RAVERSE" || exit 1

DOMAIN="omnilucient.com"
HOST="verify.omnilucient.com"
TUNNEL_ID="a241e27b-336e-44cc-9a52-6487131db63b"
TARGET="${TUNNEL_ID}.cfargotunnel.com"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVID="verification_artifacts/cloudflare_final_ownership/${STAMP}"
mkdir -p "$EVID"

exec > >(tee "$EVID/report.txt") 2>&1

echo "=================================================="
echo " UL7RAVERSE CLOUDFLARE FINAL OWNERSHIP GATE"
echo "=================================================="
echo "DOMAIN=$DOMAIN"
echo "HOST=$HOST"
echo "TUNNEL_ID=$TUNNEL_ID"
echo "TARGET=$TARGET"
echo "EVIDENCE=$EVID"
echo

# --------------------------------------------------
# 1. DELEGATION
# --------------------------------------------------

echo "=== 1. DNS DELEGATION ==="

NS="$(dig +short NS "$DOMAIN" | sed 's/\.$//' | sort -u)"

if [ -z "$NS" ]; then
    echo "DELEGATION=FAIL"
    echo "FINAL_DECISION=NS_UNRESOLVED"
    exit 2
fi

echo "$NS"

CF_NS_COUNT=0

while IFS= read -r n; do
    case "$n" in
        *.ns.cloudflare.com)
            CF_NS_COUNT=$((CF_NS_COUNT+1))
            ;;
    esac
done <<< "$NS"

if [ "$CF_NS_COUNT" -ge 2 ]; then
    echo "CLOUDFLARE_DELEGATION=PASS"
else
    echo "CLOUDFLARE_DELEGATION=FAIL"
    echo "FINAL_DECISION=NOT_CLOUDFLARE_DELEGATED"
    exit 3
fi

# --------------------------------------------------
# 2. AUTHORITATIVE DNS
# --------------------------------------------------

echo
echo "=== 2. AUTHORITATIVE DNS ==="

AUTH_RECORD=""

while IFS= read -r n; do
    [ -z "$n" ] && continue

    echo "--- $n ---"

    R="$(dig @"$n" CNAME "$HOST" +short 2>/dev/null \
        | sed 's/\.$//' | head -1)"

    if [ -n "$R" ]; then
        echo "CNAME=$R"
        AUTH_RECORD="$R"
    else
        echo "CNAME=NONE"
    fi
done <<< "$NS"

echo "AUTHORITATIVE_CNAME=${AUTH_RECORD:-NONE}"

# --------------------------------------------------
# 3. LOCAL TUNNEL CREDENTIAL
# --------------------------------------------------

echo
echo "=== 3. EXISTING TUNNEL CREDENTIAL ==="

CRED="$HOME/.cloudflared/${TUNNEL_ID}.json"

if [ ! -f "$CRED" ]; then
    echo "TUNNEL_CREDENTIAL=FAIL"
    echo "FINAL_DECISION=TUNNEL_CREDENTIAL_MISSING"
    exit 4
fi

echo "TUNNEL_CREDENTIAL=FOUND"

python3 - "$CRED" >"$EVID/tunnel_identity.txt" <<'PY'
import json,sys

p=sys.argv[1]

try:
    d=json.load(open(p))

    print("credential_json=VALID")
    print("AccountTag=", d.get("AccountTag",""))
    print("TunnelID=", d.get("TunnelID",""))
    print("TunnelSecretPresent=", bool(d.get("TunnelSecret")))

except Exception as e:
    print("credential_json=INVALID")
    print("ERROR=",e)
PY

cat "$EVID/tunnel_identity.txt"

# --------------------------------------------------
# 4. LOCAL CLOUDFLARED CONFIG
# --------------------------------------------------

echo
echo "=== 4. TUNNEL CONFIGURATION ==="

CFG="products/ul7ra-verify/evidence/convergence/20260822T111810Z/cloudflared-config.yml"

if [ ! -f "$CFG" ]; then
    echo "CONFIG=FAIL"
    echo "FINAL_DECISION=TUNNEL_CONFIG_MISSING"
    exit 5
fi

echo "CONFIG=FOUND"

grep -E \
'^(tunnel:|credentials-file:|[[:space:]]+- hostname:|[[:space:]]+service:)' \
"$CFG" | tee "$EVID/config.txt"

echo
echo "=== 5. EXISTING TUNNEL INGRESS VALIDATION ==="

if cloudflared tunnel --config "$CFG" ingress validate \
   >"$EVID/ingress.txt" 2>&1; then

    echo "INGRESS_VALIDATION=PASS"
    cat "$EVID/ingress.txt"
else
    echo "INGRESS_VALIDATION=FAIL"
    cat "$EVID/ingress.txt"
fi

# --------------------------------------------------
# 6. CLOUDFLARE API TOKEN — OPTIONAL
# --------------------------------------------------

echo
echo "=== 6. CLOUDFLARE API ACCOUNT CHECK ==="

CF_TOKEN="${CF_API_TOKEN:-}"

if [ -z "$CF_TOKEN" ]; then

    echo "CF_API_TOKEN=NOT_PRESENT"
    echo "API_ACCOUNT_CHECK=SKIPPED"

else

    echo "CF_API_TOKEN=PRESENT"

    API="https://api.cloudflare.com/client/v4"

    curl -fsS \
      -H "Authorization: Bearer $CF_TOKEN" \
      "$API/user/tokens/verify" \
      >"$EVID/token.json" 2>/dev/null || true

    python3 - "$EVID/token.json" <<'PY'
import json,sys

try:
    d=json.load(open(sys.argv[1]))
    print("TOKEN_API_SUCCESS=",d.get("success"))

    if d.get("errors"):
        print("TOKEN_ERRORS=",d["errors"])

except:
    print("TOKEN_API_RESPONSE=UNAVAILABLE")
PY

    echo
    echo "=== ZONE LOOKUP ==="

    curl -fsS \
      -H "Authorization: Bearer $CF_TOKEN" \
      "$API/zones?name=$DOMAIN" \
      >"$EVID/zone.json" 2>/dev/null || true

    python3 - "$EVID/zone.json" <<'PY'
import json,sys

try:
    d=json.load(open(sys.argv[1]))

    if not d.get("success"):
        print("ZONE_LOOKUP=FAIL")
        print(d.get("errors"))
        raise SystemExit

    r=d.get("result",[])

    if not r:
        print("ZONE_FOUND=NO")
    else:
        z=r[0]

        print("ZONE_FOUND=YES")
        print("ZONE_ID=",z.get("id"))
        print("ZONE_NAME=",z.get("name"))
        print("ZONE_STATUS=",z.get("status"))
        print("ZONE_ACCOUNT_ID=",z.get("account",{}).get("id"))
        print("ZONE_ACCOUNT_NAME=",z.get("account",{}).get("name"))
        print("ZONE_NAME_SERVERS=",z.get("name_servers"))

except Exception as e:
    print("ZONE_LOOKUP=UNAVAILABLE")
    print("ERROR=",e)
PY

    ZONE_ID="$(python3 - "$EVID/zone.json" <<'PY'
import json,sys

try:
    d=json.load(open(sys.argv[1]))
    r=d.get("result",[])
    print(r[0].get("id","") if r else "")
except:
    print("")
PY
)"

    if [ -n "$ZONE_ID" ]; then

        echo
        echo "=== CLOUDFLARE DNS RECORD ==="

        curl -fsS \
          -H "Authorization: Bearer $CF_TOKEN" \
          "$API/zones/$ZONE_ID/dns_records?name=$HOST" \
          >"$EVID/dns_record.json" 2>/dev/null || true

        python3 - "$EVID/dns_record.json" "$TARGET" <<'PY'
import json,sys

target=sys.argv[2]

try:
    d=json.load(open(sys.argv[1]))

    if not d.get("success"):
        print("DNS_API=FAIL")
        print(d.get("errors"))
        raise SystemExit

    records=d.get("result",[])

    if not records:
        print("CLOUDFLARE_RECORD=NOT_FOUND")
    else:
        for r in records:
            print("CLOUDFLARE_RECORD=FOUND")
            print("TYPE=",r.get("type"))
            print("NAME=",r.get("name"))
            print("CONTENT=",r.get("content"))
            print("PROXIED=",r.get("proxied"))
            print("TTL=",r.get("ttl"))

            if r.get("content","").rstrip(".")==target:
                print("TUNNEL_TARGET=CORRECT")
            else:
                print("TUNNEL_TARGET=DIFFERENT")

except Exception as e:
    print("DNS_API=UNAVAILABLE")
    print("ERROR=",e)
PY

    fi
fi

# --------------------------------------------------
# 7. PUBLIC RESOLVERS
# --------------------------------------------------

echo
echo "=== 7. PUBLIC RESOLUTION ==="

echo "--- Cloudflare 1.1.1.1 ---"

dig @1.1.1.1 CNAME "$HOST" +noall +answer \
    | tee "$EVID/1111_cname.txt"

dig @1.1.1.1 A "$HOST" +noall +answer \
    | tee "$EVID/1111_a.txt"

echo
echo "--- Google 8.8.8.8 ---"

dig @8.8.8.8 CNAME "$HOST" +noall +answer \
    | tee "$EVID/8888_cname.txt"

dig @8.8.8.8 A "$HOST" +noall +answer \
    | tee "$EVID/8888_a.txt"

# --------------------------------------------------
# 8. TRACE
# --------------------------------------------------

echo
echo "=== 8. DNS TRACE ==="

dig +trace CNAME "$HOST" \
    >"$EVID/trace.txt" 2>&1 || true

tail -50 "$EVID/trace.txt"

# --------------------------------------------------
# 9. FINAL DECISION
# --------------------------------------------------

echo
echo "=================================================="
echo " FINAL DECISION"
echo "=================================================="

PUBLIC="$(dig @1.1.1.1 +short CNAME "$HOST" 2>/dev/null \
    | sed 's/\.$//' | head -1)"

if [ "$AUTH_RECORD" = "$TARGET" ]; then

    echo "CLOUDFLARE_DELEGATION=PASS"
    echo "AUTHORITATIVE_CNAME=PASS"
    echo "FINAL_DECISION=DNS_AUTHORITY_READY"

elif [ -n "$PUBLIC" ]; then

    echo "PUBLIC_CNAME=$PUBLIC"

    if [ "$PUBLIC" = "$TARGET" ]; then
        echo "PUBLIC_DNS=PASS"
        echo "FINAL_DECISION=DNS_PUBLIC_READY"
    else
        echo "PUBLIC_DNS=DIFFERENT_TARGET"
        echo "FINAL_DECISION=DNS_RECORD_MISMATCH"
    fi

elif [ -z "$AUTH_RECORD" ]; then

    echo "AUTHORITATIVE_CNAME=NONE"
    echo "PUBLIC_CNAME=NONE"

    if [ -n "$CF_TOKEN" ]; then
        echo "API_TOKEN_AVAILABLE=YES"
        echo "FINAL_DECISION=AUTHORITATIVE_ZONE_RECORD_MISSING"
    else
        echo "API_TOKEN_AVAILABLE=NO"
        echo "FINAL_DECISION=AUTHORITATIVE_ZONE_RECORD_MISSING"
    fi

else

    echo "AUTHORITATIVE_CNAME=$AUTH_RECORD"
    echo "EXPECTED=$TARGET"
    echo "FINAL_DECISION=AUTHORITATIVE_RECORD_MISMATCH"

fi

echo
echo "EVIDENCE_PATH=$EVID"
echo "=================================================="
