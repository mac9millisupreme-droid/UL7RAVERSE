#!/usr/bin/env bash
set -euo pipefail
ROOT="${ROOT:-$HOME/UL7RAVERSE}"
echo "REVENUE_PRECHECK: ROOT=$ROOT"
[ -d "$ROOT" ] || { echo "ROOT_NOT_FOUND"; exit 1; }
echo "REVENUE_PRECHECK: PASS"
