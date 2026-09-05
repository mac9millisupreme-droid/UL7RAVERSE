#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

PRODUCT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-8787}"

cd "$PRODUCT"

echo "Starting UL7RA Verify on :$PORT"
exec python3 app/server.py
