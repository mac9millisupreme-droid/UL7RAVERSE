#!/data/data/com.termux/files/usr/bin/bash
set -u

ROOT="$HOME/UL7RAVERSE"
cd "$ROOT" || exit 1

echo "=== UL7RA STACK START ==="

# Start verifier if it isn't already listening
if ! curl -sS --max-time 1 http://127.0.0.1:8787/ >/dev/null 2>&1; then
    nohup python3 products/ul7ra-verify/app/server.py \
        > "$HOME/ul7ra_verify_server.log" 2>&1 &
    sleep 2
fi

# Start named Cloudflare tunnel if it isn't already running
if ! pgrep -f "cloudflared tunnel run ul7ra-verify" >/dev/null 2>&1; then
    nohup cloudflared tunnel run ul7ra-verify \
        > "$HOME/ul7ra_cloudflared.log" 2>&1 &
    sleep 4
fi

echo
echo "=== VERIFY ==="
curl -sS --max-time 3 http://127.0.0.1:8787/ || true

echo
echo "=== CLOUDFLARED ==="
pgrep -af cloudflared || true

echo
echo "=== SENTINEL ==="
./ul7ra_termux_sentinel.sh | tail -12
