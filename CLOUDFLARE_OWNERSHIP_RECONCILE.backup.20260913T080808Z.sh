#!/data/data/com.termux/files/usr/bin/bash
set -u

cd "$HOME/UL7RAVERSE" || exit 1

DOMAIN="omnilucient.com"
HOST="verify.omnilucient.com"
TUNNEL_ID="a241e27b-336e-44cc-9a52-6487131db63b"
TARGET="${TUNNEL_ID}.cfargotunnel.com"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVID="verification_artifacts/cloudflare_ownership/${STAMP}"
mkdir -p "$EVID"

exec > >(tee "$EVID/report.txt") 2>&1

echo "=================================================="
echo " UL7RAVERSE CLOUDFLARE OWNERSHIP RECONCILIATION"
echo "=================================================="
echo "DOMAIN=$DOMAIN"
echo "HOST=$HOST"
echo "TUNNEL_ID=$TUNNEL_ID"
echo "EXPECTED_TARGET=$TARGET"
echo "EVIDENCE=$EVID"
echo

# --------------------------------------------------
# 1. AUTHORITATIVE DNS
# --------------------------------------------------

echo "=== 1. AUTHORITATIVE DNS ==="

NS="$(dig +short NS "$DOMAIN" | sed 's/\.$//' | sort -u)"

if [ -z "$NS" ]; then
    echo "NS_LOOKUP=FAIL"
    echo "FINAL_DECISION=AUTHORITATIVE_NS_UNRESOLVED"
    exit 2
fi

echo "$NS"

CLOUDFLARE_NS=0

while IFS= read -r n; do
    case "$n" in
        *.ns.cloudflare.com)
            CLOUDFLARE_NS=$((CLOUDFLARE_NS+1))
            ;;
    esac
done <<< "$NS"

if [ "$CLOUDFLARE_NS" -ge 2 ]; then
    echo "CLOUDFLARE_DELEGATION=PASS"
else
    echo "CLOUDFLARE_DELEGATION=FAIL"
    echo "FINAL_DECISION=DOMAIN_NOT_DELEGATED_TO_CLOUDFLARE"
    exit 3
fi

echo
echo "=== 2. AUTHORITATIVE RECORD ==="

for n in $NS; do
    echo "--- $n ---"
    dig @"$n" CNAME "$HOST" +noall +answer || true
done

echo
echo "=== 3. LOCAL CLOUDFLARE CREDENTIAL ==="

CRED="$HOME/.cloudflared/${TUNNEL_ID}.json"

if [ -f "$CRED" ]; then
    echo "TUNNEL_CREDENTIAL=FOUND"

    python3 - "$CRED" <<'PY'
import json,sys

p=sys.argv[1]

try:
    d=json.load(open(p))
    print("credential_json=VALID")
    print("account_tag_present=", bool(d.get("AccountTag")))
    print("tunnel_id_present=", bool(d.get("TunnelID") or d.get("TunnelSecret")))
    print("tunnel_secret_present=", bool(d.get("TunnelSecret")))
except Exception as e:
    print("credential_json=INVALID")
PY

else
    echo "TUNNEL_CREDENTIAL=NOT_FOUND"
fi

echo
echo "=== 4. CLOUDFLARE API ACCESS ==="

if [ -z "${CF_API_TOKEN:-}" ]; then
    echo "CF_API_TOKEN=NOT_PRESENT"
    echo
    echo "API_INSPECTION=SKIPPED"
    echo
    echo "The local tunnel credential can prove tunnel ownership,"
    echo "but cannot safely prove which Cloudflare dashboard account"
    echo "currently owns the DNS zone."
    echo
    echo "Set CF_API_TOKEN in the shell and rerun this SAME script"
    echo "if you want account-level ownership verification."
    echo
else
    echo "CF_API_TOKEN=PRESENT"

    API="https://api.cloudflare.com/client/v4"

    echo
    echo "--- TOKEN IDENTITY ---"

    curl -fsS \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      "$API/user/tokens/verify" \
      >"$EVID/token_verify.json" 2>/dev/null || true

    python3 - "$EVID/token_verify.json" <<'PY'
import json,sys
try:
    d=json.load(open(sys.argv[1]))
    print("TOKEN_VALID=", d.get("success"))
except:
    print("TOKEN_VERIFY=UNAVAILABLE")
PY

    echo
    echo "--- ZONE LOOKUP ---"

    curl -fsS \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      "$API/zones?name=$DOMAIN" \
      >"$EVID/zone.json" 2>/dev/null || true

    python3 - "$EVID/zone.json" <<'PY'
import json,sys

try:
    d=json.load(open(sys.argv[1]))

    if not d.get("success"):
        print("ZONE_LOOKUP=API_ERROR")
        print(d.get("errors"))
        raise SystemExit

    r=d.get("result",[])

    if not r:
        print("ZONE_FOUND=NO")
        print("ZONE_ACCOUNT=UNKNOWN")
    else:
        z=r[0]
        print("ZONE_FOUND=YES")
        print("ZONE_ID=",z.get("id"))
        print("ZONE_NAME=",z.get("name"))
        print("ZONE_STATUS=",z.get("status"))
        print("ZONE_NAME_SERVERS=",z.get("name_servers"))
        print("ZONE_ACCOUNT_ID=",z.get("account",{}).get("id"))
        print("ZONE_ACCOUNT_NAME=",z.get("account",{}).get("name"))
except Exception as e:
    print("ZONE_PARSE_ERROR=",e)
PY

    echo
    echo "--- DNS RECORD LOOKUP ---"

    ZONE_ID="$(python3 - "$EVID/zone.json" <<'PY'
import json,sys
try:
    d=json.load(open(sys.argv[1]))
    r=d.get("result",[])
    print(r[0].get("id","") if r else "")
except:
    pass
PY
)"

    if [ -n "$ZONE_ID" ]; then
        curl -fsS \
          -H "Authorization: Bearer $CF_API_TOKEN" \
          "$API/zones/$ZONE_ID/dns_records?type=CNAME&name=$HOST" \
          >"$EVID/dns_record.json" 2>/dev/null || true

        python3 - "$EVID/dns_record.json" <<'PY'
import json,sys

try:
    d=json.load(open(sys.argv[1]))

    if not d.get("success"):
        print("DNS_API_LOOKUP=ERROR")
        print(d.get("errors"))
        raise SystemExit

    r=d.get("result",[])

    if not r:
        print("CLOUDFLARE_ZONE_RECORD=NOT_FOUND")
    else:
        for x in r:
            print("CLOUDFLARE_ZONE_RECORD=FOUND")
            print("TYPE=",x.get("type"))
            print("NAME=",x.get("name"))
            print("CONTENT=",x.get("content"))
            print("PROXIED=",x.get("proxied"))
            print("TTL=",x.get("ttl"))

            if x.get("content","").rstrip(".") == \
               "a241e27b-336e-44cc-9a52-6487131db63b.cfargotunnel.com":
                print("TUNNEL_CNAME=CORRECT")
            else:
                print("TUNNEL_CNAME=DIFFERENT")
except Exception as e:
    print("DNS_PARSE_ERROR=",e)
PY
    fi

    echo
    echo "--- TUNNEL LOOKUP ---"

    curl -fsS \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      "$API/accounts" \
      >"$EVID/accounts.json" 2>/dev/null || true

    python3 - "$EVID/accounts.json" <<'PY'
import json,sys

try:
    d=json.load(open(sys.argv[1]))
    if d.get("success"):
        print("API_ACCOUNTS_LOOKUP=PASS")
        for a in d.get("result",[]):
            print("ACCOUNT_ID=",a.get("id"))
            print("ACCOUNT_NAME=",a.get("name"))
    else:
        print("API_ACCOUNTS_LOOKUP=FAIL")
except:
    print("API_ACCOUNTS_LOOKUP=UNAVAILABLE")
PY
fi

# --------------------------------------------------
# 5. PUBLIC DNS
# --------------------------------------------------

echo
echo "=== 5. PUBLIC DNS ==="

echo "--- 1.1.1.1 ---"
dig @1.1.1.1 CNAME "$HOST" +noall +answer
dig @1.1.1.1 A "$HOST" +noall +answer

echo
echo "--- 8.8.8.8 ---"
dig @8.8.8.8 CNAME "$HOST" +noall +answer
dig @8.8.8.8 A "$HOST" +noall +answer

echo
echo "=== 6. FINAL OWNERSHIP DIAGNOSIS ==="

AUTH_RECORD=""

for n in $NS; do
    x="$(dig @"$n" CNAME "$HOST" +short 2>/dev/null | sed 's/\.$//' | head -1)"
    if [ -n "$x" ]; then
        AUTH_RECORD="$x"
        break
    fi
done

PUBLIC_RECORD="$(dig @1.1.1.1 CNAME "$HOST" +short 2>/dev/null | sed 's/\.$//' | head -1)"

echo "AUTHORITATIVE_CNAME=${AUTH_RECORD:-NONE}"
echo "PUBLIC_CNAME=${PUBLIC_RECORD:-NONE}"

if [ "$AUTH_RECORD" = "$TARGET" ]; then
    echo "AUTHORITATIVE_TUNNEL_RECORD=PASS"
    echo "FINAL_DECISION=DNS_AUTHORITY_READY"
elif [ -n "$CF_API_TOKEN" ] && \
     grep -q '"content":"'"$TARGET"'"' "$EVID/dns_record.json" 2>/dev/null; then
    echo "CLOUDFLARE_API_RECORD=PASS"
    echo "AUTHORITATIVE_DNS=NOT_SERVING_EXPECTED_RECORD"
    echo "FINAL_DECISION=CLOUDFLARE_ZONE_ACCOUNT_MISMATCH_OR_DELEGATION_STATE"
elif [ -z "$AUTH_RECORD" ]; then
    echo "AUTHORITATIVE_CNAME=ABSENT"
    echo "FINAL_DECISION=AUTHORITATIVE_ZONE_RECORD_MISSING"
else
    echo "AUTHORITATIVE_CNAME=DIFFERENT"
    echo "FINAL_DECISION=AUTHORITATIVE_RECORD_MISMATCH"
fi

echo
echo "EVIDENCE_PATH=$EVID"
echo "=================================================="
