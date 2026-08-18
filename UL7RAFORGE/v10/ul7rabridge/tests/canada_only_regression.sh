#!/data/data/com.termux/files/usr/bin/bash
set -eu

BASE="$(cd "$(dirname "$0")/.." && pwd)"
POLICY="$BASE/canada/policy/canada_only.json"

python - "$POLICY" <<'PY'
import json, sys

p = json.load(open(sys.argv[1]))

assert p["policy"] == "CANADA_ONLY"
assert p["default"] == "DENY"
assert p["allowed_data_jurisdiction"] == ["CA"]
assert p["allowed_egress"] == "EXPLICIT_ALLOWLIST_ONLY"
assert p["dns"] == "CONTROLLED"
assert p["backups"] == "CANADA_ONLY"
assert p["replication"] == "CANADA_ONLY"
assert p["telemetry"] == "CANADA_ONLY"
assert p["keys"] == "CANADA_CONTROLLED"
assert p["non_canadian_route"] == "DENY"
assert p["production"] == "LOCKED"

print("CANADA DATA JURISDICTION = PASS")
print("EGRESS DEFAULT DENY = PASS")
print("BACKUP RESIDENCY = PASS")
print("REPLICATION RESIDENCY = PASS")
print("TELEMETRY RESIDENCY = PASS")
print("KEY CONTROL POLICY = PASS")
print("NON-CANADIAN ROUTE = DENY")
PY

echo "CANADA-ONLY POLICY REGRESSION = PASS"
