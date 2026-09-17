#!/data/data/com.termux/files/usr/bin/bash
set -u

cd "$HOME/UL7RAVERSE" || exit 1

HOST="verify.omnilucient.com"
ZONE="omnilucient.com"
TARGET="a241e27b-336e-44cc-9a52-6487131db63b.cfargotunnel.com"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVID="verification_artifacts/dns_authority_final/${STAMP}"
mkdir -p "$EVID"

exec > >(tee "$EVID/report.txt") 2>&1

echo "=============================================="
echo " UL7RAVERSE DNS AUTHORITY FINAL GATE"
echo "=============================================="
echo "HOST=$HOST"
echo "ZONE=$ZONE"
echo "EXPECTED_CNAME=$TARGET"
echo "EVIDENCE=$EVID"
echo

echo "=== 1. PUBLIC NS ==="
dig NS "$ZONE" +noall +answer | tee "$EVID/public_ns.txt"

echo
echo "=== 2. PUBLIC SOA ==="
dig SOA "$ZONE" +noall +answer | tee "$EVID/public_soa.txt"

echo
echo "=== 3. PUBLIC CNAME ==="
dig CNAME "$HOST" +noall +answer | tee "$EVID/public_cname.txt"

echo
echo "=== 4. CLOUDFLARE RESOLVER ==="
dig @1.1.1.1 CNAME "$HOST" +noall +answer | tee "$EVID/cloudflare_cname.txt"
dig @1.1.1.1 A "$HOST" +noall +answer | tee "$EVID/cloudflare_a.txt"
dig @1.1.1.1 AAAA "$HOST" +noall +answer | tee "$EVID/cloudflare_aaaa.txt"

echo
echo "=== 5. GOOGLE RESOLVER ==="
dig @8.8.8.8 CNAME "$HOST" +noall +answer | tee "$EVID/google_cname.txt"
dig @8.8.8.8 A "$HOST" +noall +answer | tee "$EVID/google_a.txt"
dig @8.8.8.8 AAAA "$HOST" +noall +answer | tee "$EVID/google_aaaa.txt"

echo
echo "=== 6. AUTHORITATIVE NS DIRECT TEST ==="

NS_LIST="$(dig +short NS "$ZONE" | sed 's/\.$//' | sort -u)"

if [ -z "$NS_LIST" ]; then
    echo "AUTHORITATIVE_NS=UNRESOLVED"
    echo "FINAL_DECISION=DNS_AUTHORITY_UNRESOLVED"
    exit 2
fi

AUTH_PASS=0

while IFS= read -r NS; do
    [ -z "$NS" ] && continue

    echo
    echo "--- NAMESERVER: $NS ---"

    RESULT="$(dig @"$NS" CNAME "$HOST" +noall +answer 2>&1 || true)"
    echo "$RESULT"

    echo "$RESULT" >> "$EVID/authoritative_records.txt"

    if echo "$RESULT" | grep -q "$TARGET"; then
        echo "AUTHORITY_RESULT=TARGET_PRESENT"
        AUTH_PASS=1
    else
        echo "AUTHORITY_RESULT=TARGET_NOT_PRESENT"
    fi
done <<< "$NS_LIST"

echo
echo "=== 7. TRACE ==="
dig +trace CNAME "$HOST" >"$EVID/trace.txt" 2>&1 || true

tail -80 "$EVID/trace.txt"

echo
echo "=== 8. DECISION ==="

PUBLIC_CNAME="$(dig @1.1.1.1 +short CNAME "$HOST" 2>/dev/null | sed 's/\.$//' | head -1)"

if [ "$PUBLIC_CNAME" = "$TARGET" ]; then
    echo "PUBLIC_DNS=PASS"
    echo "EXPECTED_TARGET=CONFIRMED"
    echo "FINAL_DECISION=DNS_READY"
    exit 0
fi

if [ "$AUTH_PASS" -eq 1 ]; then
    echo "AUTHORITATIVE_DNS=PASS"
    echo "PUBLIC_RESOLVER=NOT_YET_CONVERGED"
    echo "FINAL_DECISION=DNS_PROPAGATION_PENDING"
    exit 3
fi

echo "AUTHORITATIVE_DNS=FAIL"
echo "TARGET_NOT_FOUND_AT_AUTHORITATIVE_NAMESERVERS"
echo "FINAL_DECISION=DNS_AUTHORITY_MISMATCH"
exit 4
