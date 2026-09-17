#!/data/data/com.termux/files/usr/bin/bash
set -u

ROOT="$HOME/UL7RAVERSE"
BASE="$ROOT/verification_artifacts/omnipulse/force-live"
LATEST="$(find "$BASE" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | tail -1)"
OUT="$LATEST/network-diagnostic-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT"

PORT=8899
LOCAL="http://127.0.0.1:$PORT"

echo "============================================================"
echo " OMNIPULSE NETWORK / CLOUDFLARE DIAGNOSTIC"
echo "============================================================"

echo
echo "LATEST=$LATEST"
echo

echo "=== LOCAL ==="
curl -sS --connect-timeout 3 --max-time 8 \
  -o "$OUT/local.html" -w 'LOCAL_HTTP=%{http_code}\n' \
  "$LOCAL/" 2>"$OUT/local.err" || true

echo
echo "=== DNS: CLOUDFLARE ==="
getent hosts cloudflare.com 2>&1 | tee "$OUT/dns_cloudflare.txt" || true

echo
echo "=== HTTPS: CLOUDFLARE ==="
curl -I -L -sS \
  --connect-timeout 5 --max-time 12 \
  https://cloudflare.com \
  -o "$OUT/cloudflare_headers.txt" \
  -w 'CLOUDFLARE_HTTP=%{http_code}\n' \
  2>"$OUT/cloudflare.err" || true

PUBLIC_URL="$(
  find "$BASE" -name 'cloudflare.log' -type f -print0 2>/dev/null |
  xargs -0 cat 2>/dev/null |
  grep -Eo 'https://[-a-zA-Z0-9]+\.trycloudflare\.com' |
  tail -1
)"

echo
echo "=== TUNNEL ==="
echo "PUBLIC_URL=$PUBLIC_URL"

if [ -z "$PUBLIC_URL" ]; then
  echo "TUNNEL_URL=NOT_FOUND"
  echo "FINAL_DECISION=BLOCKED"
  exit 1
fi

HOST="${PUBLIC_URL#https://}"
echo "TUNNEL_HOST=$HOST"

echo
echo "=== DNS: TUNNEL ==="
getent hosts "$HOST" 2>&1 | tee "$OUT/dns_tunnel.txt" || true

echo
echo "=== HTTPS: TUNNEL ==="

curl -L -sS \
  --connect-timeout 8 \
  --max-time 15 \
  -o "$OUT/tunnel.html" \
  -w 'TUNNEL_HTTP=%{http_code}\nREMOTE_IP=%{remote_ip}\nSSL_VERIFY=%{ssl_verify_result}\n' \
  "$PUBLIC_URL/" \
  2>"$OUT/tunnel.err" || true

echo
echo "=== TUNNEL CURL ERROR ==="
cat "$OUT/tunnel.err" 2>/dev/null || true

echo
echo "=== CLOUDFLARE LOG ==="
find "$BASE" -name 'cloudflare.log' -type f -print0 2>/dev/null |
xargs -0 cat 2>/dev/null |
tail -80 || true

echo
echo "=== CLOUDflared PROCESS ==="
ps -ef 2>/dev/null | grep '[c]loudflared' || true

echo
echo "=== ROUTING ==="
ip route 2>/dev/null || true

echo
echo "=== RESULT ==="

if curl -sS --connect-timeout 3 --max-time 8 \
   "$PUBLIC_URL/" -o "$OUT/final.html" >/dev/null 2>&1; then
  echo "PUBLIC_NETWORK_REACHABLE=1"
else
  echo "PUBLIC_NETWORK_REACHABLE=0"
fi

echo "LOCAL_HTTP_EXPECTED=200"
echo "PUBLIC_HTTP_REQUIRES_REACHABILITY=1"
echo "PRODUCTION_UNLOCK=0"
echo "FINAL_DECISION=BLOCKED"

echo
echo "REPORT=$OUT"
echo "============================================================"
