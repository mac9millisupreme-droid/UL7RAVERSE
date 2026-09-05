#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

pkill -f "products/ul7ra-verify/app/server.py" 2>/dev/null || true
echo "UL7RA Verify local service stopped"
