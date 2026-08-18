#!/data/data/com.termux/files/usr/bin/bash
set -eu

STATUS="../ul7rastack/security/state/live_security.json"

python - "$STATUS" <<'PY'
import json
import sys

s = json.load(open(sys.argv[1]))

assert s["security_status"] == "VERIFIED_WITH_SCOPE"
assert s["detected_violations"] == 0
assert s["unresolved_exceptions"] == 0
assert s["evidence_freshness"] == "CURRENT"
assert s["production"] == "LOCKED"

required = [
    "cheetah_policy",
    "ghost_policy",
    "bridge_invariant",
    "os_baseline",
    "canada_only_policy",
    "attestation_integrity",
    "tamper_detection"
]

for control in required:
    assert s["active_controls"][control] == "VERIFIED"

# Unknowns must never disappear merely to obtain a green status.
assert len(s["unknowns"]) > 0

print("SECURITY ASSURANCE = PASS")
print("ACTIVE CONTROLS = PASS")
print("VIOLATIONS = 0")
print("EXCEPTIONS = 0")
print("EVIDENCE FRESHNESS = CURRENT")
print("UNKNOWN DISCLOSURE = PASS")
print("PRODUCTION = LOCKED")
PY
