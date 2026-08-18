#!/data/data/com.termux/files/usr/bin/bash
set -eu

python - <<'PY'
import json

p = "v10/ul7rastack/assurance/state/high_assurance.json"
d = json.load(open(p))

assert d["profile"] == "HIGH_ASSURANCE"
assert d["controls_total"] >= d["controls_passed"]
assert d["production"] == "LOCKED"
assert d["certification_claim"] is False
assert d["evidence_hash"]

if d["unknown_or_unverified"]:
    assert d["status"] == "BLOCKED"
else:
    assert d["status"] == "ELIGIBLE_FOR_EXTERNAL_ASSESSMENT"

print("HIGH-ASSURANCE PROFILE = PASS")
print(f"CONTROLS = {d['controls_passed']}/{d['controls_total']}")
print(f"UNVERIFIED = {len(d['unknown_or_unverified'])}")
print(f"STATUS = {d['status']}")
print("CERTIFICATION CLAIM = DISABLED")
print("PRODUCTION = LOCKED")
PY
