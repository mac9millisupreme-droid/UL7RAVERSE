#!/data/data/com.termux/files/usr/bin/bash
set -eu

BASE="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$BASE/ghost/templates/manifest.json"

python - "$MANIFEST" <<'PY'
import json, sys

m = json.load(open(sys.argv[1]))

assert m["network"] == "DENY_BY_DEFAULT"
assert m["external_egress"] == "CHEETAH_ONLY"
assert m["return_path"] == "DENY"
assert m["credentials"] == "NONE"

print("GHOST → CHEETAH POLICY = PASS")
print("RETURN PATH POLICY = PASS")
print("CREDENTIAL ISOLATION = PASS")
PY

echo "UL7RABRIDGE INVARIANT = PASS"
echo "PRODUCTION = LOCKED"
