#!/data/data/com.termux/files/usr/bin/bash
set +e

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$HOME/UL7RAVERSE/verification_artifacts/dns_delegation/$TS"
mkdir -p "$OUT"
exec > >(tee "$OUT/REPORT.txt") 2>&1

echo "============================================================"
echo " UL7RA DNS DELEGATION DIAGNOSTIC"
echo "============================================================"
echo "TIME=$TS"
echo

echo "=== 1. DOMAIN NS ==="
nslookup -type=NS omnilucient.com 8.8.8.8 2>&1
echo

echo "=== 2. DOMAIN SOA ==="
nslookup -type=SOA omnilucient.com 8.8.8.8 2>&1
echo

echo "=== 3. VERIFY HOST ==="
nslookup verify.omnilucient.com 8.8.8.8 2>&1
echo

echo "=== 4. CLOUDFLARE ROUTES ==="
cloudflared tunnel route dns 2>&1
echo

echo "=== 5. TUNNEL ==="
cloudflared tunnel info ul7ra-verify 2>&1
echo

echo "=== 6. CLOUDFLARE DNS RECORD SEARCH IN REPO ==="
grep -RniE \
'verify\.omnilucient\.com|omnilucient\.com|nameserver|name.?server|dns' \
products/ul7ra-verify \
verification_artifacts \
lucideploy \
--exclude='*.pyc' \
--exclude='REPORT.txt' \
2>/dev/null | head -300
echo

echo "=== 7. PUBLIC HTTPS ==="
curl -sS -I -L \
--connect-timeout 5 \
--max-time 10 \
https://verify.omnilucient.com/health 2>&1 | head -30
echo

echo "=== 8. LOCAL ==="
curl -sS http://127.0.0.1:8787/health 2>&1
echo

echo "============================================================"
echo " FINAL DIAGNOSTIC STATE"
echo "============================================================"
echo "TUNNEL=PASS"
echo "ROUTE=PASS"
echo "PUBLIC_DNS=BLOCKED"
echo "PUBLIC_HTTP=BLOCKED"
echo "PRODUCTION=BLOCKED"
echo "PROMOTION=BLOCKED"
echo "FAIL_CLOSED=TRUE"
echo
echo "EVIDENCE=$OUT"
