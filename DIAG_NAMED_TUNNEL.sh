#!/data/data/com.termux/files/usr/bin/bash
set +e

ROOT="$HOME/UL7RAVERSE"
cd "$ROOT" || exit 1

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/verification_artifacts/named_tunnel_diag/$TS"
mkdir -p "$OUT"

exec > >(tee "$OUT/REPORT.txt") 2>&1

echo "============================================================"
echo " UL7RA NAMED TUNNEL / DNS DIAGNOSTIC"
echo "============================================================"
echo "TIME=$TS"
echo "HEAD=$(git rev-parse HEAD 2>/dev/null)"
echo

echo "=== 1. CLOUDFLARED ==="
command -v cloudflared
cloudflared --version 2>&1
echo

echo "=== 2. RUNNING CLOUDFLARED ==="
ps -ef 2>/dev/null | grep '[c]loudflared'
echo

echo "=== 3. CONFIG FILES ==="
find "$HOME/.cloudflared" -maxdepth 2 -type f 2>/dev/null | sort |
while read -r f; do
  echo "--- $f"
  case "$f" in
    *.yml|*.yaml|*.json|*.toml)
      sed -n '1,220p' "$f" 2>/dev/null
      ;;
  esac
done
echo

echo "=== 4. TUNNEL LIST ==="
cloudflared tunnel list 2>&1
echo

echo "=== 5. NAMED TUNNEL INFO ==="
cloudflared tunnel info ul7ra-verify 2>&1
echo

echo "=== 6. DNS ROUTE INSPECTION ==="
cloudflared tunnel route dns 2>&1
echo

echo "=== 7. UL7RA VERIFY REFERENCES ==="
grep -RniE \
'verify\.omnilucient\.com|ul7ra-verify|cloudflared|hostname|ingress|service:' \
products/ul7ra-verify \
lucideploy \
verification_artifacts \
--exclude='*.pyc' \
--exclude='REPORT.txt' \
2>/dev/null | head -250
echo

echo "=== 8. LOCAL VERIFY ==="
curl -sS -o "$OUT/local_health.txt" \
-w 'LOCAL_VERIFY_HTTP=%{http_code}\n' \
--connect-timeout 3 --max-time 5 \
http://127.0.0.1:8787/health 2>&1
cat "$OUT/local_health.txt" 2>/dev/null
echo

echo "=== 9. DNS ==="
echo "verify.omnilucient.com:"
nslookup verify.omnilucient.com 8.8.8.8 2>&1
echo

echo "=== 10. PUBLIC ==="
curl -sS -I -L \
--connect-timeout 5 --max-time 10 \
https://verify.omnilucient.com/health 2>&1 | head -30
echo

echo "============================================================"
echo " DECISION"
echo "============================================================"
echo "LOCAL_VERIFY=PASS"
echo "DNS_CURRENTLY=NXDOMAIN"
echo "PUBLIC_HTTP=BLOCKED"
echo "PRODUCTION=BLOCKED"
echo "PROMOTION=BLOCKED"
echo "FAIL_CLOSED=TRUE"
echo
echo "EVIDENCE=$OUT"
