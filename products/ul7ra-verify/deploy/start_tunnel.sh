#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

PORT="${PORT:-8787}"

echo "Starting Cloudflare temporary tunnel"
echo "Origin: http://127.0.0.1:$PORT"

exec cloudflared tunnel --url "http://127.0.0.1:$PORT"
