#!/data/data/com.termux/files/usr/bin/bash
set -eu

BASE="$(cd "$(dirname "$0")" && pwd)"
ID="ghost-$(date +%s)-$$"
TARGET="$BASE/runtime/$ID"

mkdir -p "$TARGET"
cp "$BASE/templates/manifest.json" "$TARGET/manifest.json"

printf '%s\n' "$ID"
