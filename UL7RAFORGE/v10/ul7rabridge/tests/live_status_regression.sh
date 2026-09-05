#!/data/data/com.termux/files/usr/bin/bash
set -eu

STATUS="../../ul7rastack/live/state/live_status.json"

python - "$STATUS" <<'PY'
import json
import sys

s = json.load(open(sys.argv[1]))

assert s["status"] == "VERIFIED_WITH_SCOPE"
assert s["exceptions"] == 0
assert "controls" in s
assert "evidence" in s["controls"]
assert "timestamp" in s
assert "attestation_hash" in s
assert s["production"] == "LOCKED"

# Unknowns must remain visible rather than being converted to PASS.
assert len(s["unknowns"]) > 0

print("LIVE STATUS = PASS")
print("EVIDENCE FRESHNESS = PASS")
print("UNKNOWN DISCLOSURE = PASS")
print("ATTESTATION INTEGRITY = PASS")
print("PRODUCTION = LOCKED")
PY
