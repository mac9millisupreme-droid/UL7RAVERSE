#!/data/data/com.termux/files/usr/bin/bash
set +e

DOMAIN="omnilucient.com"
HOST="verify.$DOMAIN"
CONTROL="_ul7ra-control.$DOMAIN"
TARGET="a241e27b-336e-44cc-9a52-6487131db63b.cfargotunnel.com."
TOKEN="UL7RA-CONTROL-20260912T000358Z"

echo "============================================================"
echo " UL7RA DNS TRUTH CHECK"
echo "============================================================"

NS="$(dig NS "$DOMAIN" +short)"
echo "AUTHORITATIVE_NS:"
echo "$NS"
echo

for N in $NS; do
  echo "============================================================"
  echo "AUTHORITATIVE SERVER: $N"
  echo "============================================================"

  echo "--- VERIFY CNAME ---"
  dig @"$N" "$HOST" CNAME +noall +answer
  echo

  echo "--- CONTROL TXT ---"
  dig @"$N" "$CONTROL" TXT +noall +answer
  echo

  echo "--- SOA ---"
  dig @"$N" "$DOMAIN" SOA +noall +answer
  echo
done

echo "============================================================"
echo " PUBLIC RESOLVERS"
echo "============================================================"

for R in 1.1.1.1 8.8.8.8; do
  echo "--- $R / CNAME ---"
  dig @"$R" "$HOST" CNAME +noall +answer
  echo "--- $R / TXT ---"
  dig @"$R" "$CONTROL" TXT +short
  echo
done

echo "============================================================"
echo " DIRECT CLASSIFICATION"
echo "============================================================"

AUTH_MATCH=0
TXT_MATCH=0
PUBLIC_MATCH=0
PUBLIC_TXT=0

for N in $NS; do
  if dig @"$N" "$HOST" CNAME +short 2>/dev/null | grep -qi "$TARGET"; then
    AUTH_MATCH=$((AUTH_MATCH+1))
  fi

  if dig @"$N" "$CONTROL" TXT +short 2>/dev/null | grep -Fq "$TOKEN"; then
    TXT_MATCH=$((TXT_MATCH+1))
  fi
done

for R in 1.1.1.1 8.8.8.8; do
  if dig @"$R" "$HOST" CNAME +short 2>/dev/null | grep -qi "$TARGET"; then
    PUBLIC_MATCH=$((PUBLIC_MATCH+1))
  fi

  if dig @"$R" "$CONTROL" TXT +short 2>/dev/null | grep -Fq "$TOKEN"; then
    PUBLIC_TXT=$((PUBLIC_TXT+1))
  fi
done

echo "AUTHORITATIVE_CNAME_MATCHES=$AUTH_MATCH"
echo "AUTHORITATIVE_TXT_MATCHES=$TXT_MATCH"
echo "PUBLIC_CNAME_MATCHES=$PUBLIC_MATCH"
echo "PUBLIC_TXT_MATCHES=$PUBLIC_TXT"
echo

if [ "$TXT_MATCH" -eq 2 ]; then
  echo "DNS_CONTROL=PROVEN"
else
  echo "DNS_CONTROL=UNPROVEN"
fi

if [ "$AUTH_MATCH" -eq 2 ]; then
  echo "AUTHORITATIVE_VERIFY_CNAME=PASS"
else
  echo "AUTHORITATIVE_VERIFY_CNAME=BLOCKED"
fi

if [ "$PUBLIC_MATCH" -eq 2 ]; then
  echo "PUBLIC_DNS=PASS"
else
  echo "PUBLIC_DNS=BLOCKED"
fi

echo
echo "=== HTTPS ==="

HTTP="$(curl -sS \
  -o /tmp/ul7ra_public_health \
  -w '%{http_code}' \
  --connect-timeout 5 \
  --max-time 15 \
  "https://$HOST/health" 2>/dev/null)"

echo "PUBLIC_HTTPS=$HTTP"

if [ "$HTTP" = "200" ]; then
  echo "PUBLIC_VERIFY=PASS"
else
  echo "PUBLIC_VERIFY=BLOCKED"
fi

echo
echo "============================================================"

if [ "$AUTH_MATCH" -eq 2 ] &&
   [ "$TXT_MATCH" -eq 2 ] &&
   [ "$PUBLIC_MATCH" -eq 2 ] &&
   [ "$HTTP" = "200" ]; then

  echo "DNS_CONTROL=PROVEN"
  echo "PUBLIC_DNS=PASS"
  echo "PUBLIC_VERIFY=PASS"
  echo "DNS_TRUTH=PASS"
  echo "PRODUCTION=HAND_OFF_TO_LUCI"

else

  echo "DNS_TRUTH=BLOCKED"
  echo "PRODUCTION=BLOCKED"
  echo "PROMOTION=BLOCKED"
  echo "FAIL_CLOSED=TRUE"
fi

echo "============================================================"
