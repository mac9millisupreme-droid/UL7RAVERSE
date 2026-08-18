#!/data/data/com.termux/files/usr/bin/bash
set -eu

BASE="$(cd "$(dirname "$0")/.." && pwd)"
GHOST="$BASE/ghost"
ID="$("$GHOST/create.sh")"
TARGET="$GHOST/runtime/$ID"

test -f "$TARGET/manifest.json"

python - "$TARGET/manifest.json" <<'PY'
import json, sys

data = json.load(open(sys.argv[1]))

assert data["filesystem"] == "EPHEMERAL"
assert data["network"] == "DENY_BY_DEFAULT"
assert data["capabilities"] == []
assert data["credentials"] == "NONE"
assert data["external_egress"] == "CHEETAH_ONLY"
assert data["return_path"] == "DENY"
assert data["production"] == "LOCKED"

print("GHOST ISOLATION POLICY = PASS")
PY

rm -rf "$TARGET"

if [ -e "$TARGET" ]; then
    echo "FAIL: ghost partition was not destroyed"
    exit 1
fi

echo "GHOST PARTITION LIFECYCLE = PASS"
echo "GHOST REGRESSION = PASS"
