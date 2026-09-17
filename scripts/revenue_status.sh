#!/usr/bin/env bash
set -euo pipefail
ROOT="${ROOT:-$HOME/UL7RAVERSE}"
STATE="$ROOT/launch/REVENUE_STATE.json"

echo "=== UL7RAVERSE REVENUE STATUS ==="
jq '.' "$STATE" 2>/dev/null || echo "REVENUE_STATE: UNAVAILABLE"
