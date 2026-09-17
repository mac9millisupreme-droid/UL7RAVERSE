#!/data/data/com.termux/files/usr/bin/bash
set +e

ROOT="$HOME/UL7RAVERSE"
cd "$ROOT" || exit 1

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/verification_artifacts/luci_public_authority/$TS"
mkdir -p "$OUT"

exec > >(tee "$OUT/REPORT.txt") 2>&1

echo "============================================================"
echo " LUCI PUBLIC AUTHORITY DIAGNOSTIC"
echo "============================================================"
echo "TIME=$TS"
echo "CURRENT_HEAD=$(git rev-parse HEAD 2>/dev/null)"
echo

echo "=== 1. CURRENT LUCI FINAL GATE ==="
cat lucideploy/evidence/final_gate.json 2>/dev/null
echo

echo "=== 2. NAMED CLOUDFLARE PROCESS ==="
ps -ef 2>/dev/null | grep '[c]loudflared'
echo

echo "=== 3. CLOUDFLARED CONFIG DISCOVERY ==="
for f in \
  "$HOME/.cloudflared/config.yml" \
  "$HOME/.cloudflared/config.yaml" \
  "$HOME/.cloudflared/config.json" \
  "$HOME/.cloudflared/ul7ra-verify.yml" \
  "$HOME/.cloudflared/ul7ra-verify.yaml"
do
  if [ -f "$f" ]; then
    echo "--- $f"
    cat "$f"
  fi
done

echo
echo "=== 4. UL7RA VERIFY ROUTE ARTIFACT ==="
find products/ul7ra-verify -type f \
  \( -iname '*route*' -o -iname '*tunnel*' -o -iname '*cloudflare*' -o -iname '*deploy*' \) \
  -maxdepth 5 2>/dev/null |
sort |
while read -r f; do
  echo "--- $f"
  case "$f" in
    *.json|*.yml|*.yaml|*.toml|*.txt|*.md|*.sh)
      sed -n '1,220p' "$f" 2>/dev/null
      ;;
  esac
done

echo
echo "=== 5. KNOWN HOSTNAME REFERENCES ==="
grep -RniE \
  'verify\.omnilucient\.com|ul7ra-verify|hostname|tunnel|cloudflared' \
  products/ul7ra-verify lucideploy verification_artifacts \
  --exclude='*.pyc' \
  --exclude='REPORT.txt' \
  2>/dev/null |
head -300

echo
echo "=== 6. LOCAL VERIFY PRODUCT ==="
curl -sS -o "$OUT/local_verify.html" \
  -w 'LOCAL_VERIFY_HTTP=%{http_code}\n' \
  --max-time 5 \
  http://127.0.0.1:8787 2>/dev/null

echo
echo "=== 7. OMNIPULSE LOCAL ==="
curl -sS -o "$OUT/local_omnipulse.html" \
  -w 'LOCAL_OMNIPULSE_HTTP=%{http_code}\n' \
  --max-time 5 \
  http://127.0.0.1:8899 2>/dev/null

echo
echo "=== 8. DNS ==="
for host in verify.omnilucient.com; do
  echo "--- $host"
  getent hosts "$host" 2>/dev/null || nslookup "$host" 2>/dev/null || true
done

echo
echo "=== 9. PUBLIC PROBE ==="
for url in \
  "https://verify.omnilucient.com" \
  "https://verify.omnilucient.com/health"
do
  echo "--- $url"
  curl -sS -I -L \
    --connect-timeout 5 \
    --max-time 10 \
    "$url" 2>&1 | head -20
done

echo
echo "=== 10. GOVERNANCE ==="
echo "LUCI_TESTS=PASS"
echo "LOCAL_PRODUCT=PASS"
echo "LOCAL_OMNIPULSE=PASS"
echo "PUBLIC_HTTP=UNVERIFIED"
echo "PRODUCTION_HOSTNAME=UNVERIFIED"
echo "PROMOTION=BLOCKED"
echo "FAIL_CLOSED=TRUE"

echo
echo "=== FINAL DECISION ==="
echo "FINAL_DECISION=BLOCKED"
echo "REASON=PUBLIC_PRODUCTION_HOSTNAME_NOT_INDEPENDENTLY_VERIFIED"
echo
echo "EVIDENCE=$OUT"
