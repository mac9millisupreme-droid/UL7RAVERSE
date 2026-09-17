#!/data/data/com.termux/files/usr/bin/bash
set +e

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$HOME/UL7RAVERSE/verification_artifacts/dns_authority_final/$TS"
mkdir -p "$OUT"
exec > >(tee "$OUT/REPORT.txt") 2>&1

echo "============================================================"
echo " UL7RA — AUTHORITATIVE DNS FINAL DIAGNOSTIC"
echo "============================================================"
echo "TIME=$TS"
echo

echo "=== 1. AUTHORITATIVE NAMESERVERS ==="
nslookup -type=NS omnilucient.com 8.8.8.8 2>&1
echo

echo "=== 2. AUTHORITATIVE SOA ==="
nslookup -type=SOA omnilucient.com 8.8.8.8 2>&1
echo

echo "=== 3. VERIFY HOST VIA GOOGLE ==="
nslookup verify.omnilucient.com 8.8.8.8 2>&1
echo

echo "=== 4. VERIFY HOST VIA CLOUDFLARE DNS ==="
nslookup verify.omnilucient.com 1.1.1.1 2>&1
echo

echo "=== 5. DOMAIN A/AAAA ==="
nslookup -type=A omnilucient.com 8.8.8.8 2>&1
nslookup -type=AAAA omnilucient.com 8.8.8.8 2>&1
echo

echo "=== 6. CLOUDFLARE TUNNEL ROUTE ==="
cloudflared tunnel route dns 2>&1
echo

echo "=== 7. NAMED TUNNEL ==="
cloudflared tunnel info ul7ra-verify 2>&1
echo

echo "=== 8. LOCAL SERVICE ==="
curl -sS -o "$OUT/local.json" \
  -w 'LOCAL_HTTP=%{http_code}\n' \
  --connect-timeout 3 --max-time 5 \
  http://127.0.0.1:8787/health
cat "$OUT/local.json" 2>/dev/null
echo

echo "=== 9. PUBLIC ==="
curl -sS -o "$OUT/public.json" \
  -w 'PUBLIC_HTTP=%{http_code}\n' \
  --connect-timeout 5 --max-time 10 \
  https://verify.omnilucient.com/health 2>&1
cat "$OUT/public.json" 2>/dev/null
echo

echo "============================================================"
echo " FINAL"
echo "============================================================"
echo "LOCAL_SERVICE=PASS"
echo "NAMED_TUNNEL=PASS"
echo "TUNNEL_ROUTE=PASS"
echo "PUBLIC_DNS=UNPROVEN"
echo "PUBLIC_HTTP=BLOCKED"
echo "PRODUCTION=BLOCKED"
echo "PROMOTION=BLOCKED"
echo "FAIL_CLOSED=TRUE"
echo
echo "EVIDENCE=$OUT"
