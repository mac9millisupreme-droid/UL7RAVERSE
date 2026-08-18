#!/data/data/com.termux/files/usr/bin/bash
set -eu

python - <<'PY'
import json

p = "v10/ul7rastack/ca/state/ca_registry_status.json"
d = json.load(open(p))

assert d["registry"] == "UL7RAVERSE_CA"
assert d["jurisdiction"] == "CA"
assert d["model"] == "CONTINUOUS_ASSURANCE"
assert d["evidence"] == "REQUIRED"
assert d["independent_verification"] == "REQUIRED"
assert d["status"] == "VERIFIED_WITH_SCOPE"
assert len(d["unknowns"]) > 0
assert d["production"] == "LOCKED"
assert d["registry_hash"]

for name, framework in d["frameworks"].items():
    assert framework["jurisdiction"] == "CA"
    assert framework["evidence_required"] is True

print("CANADIAN REGISTRY = PASS")
print("EVIDENCE REQUIREMENT = PASS")
print("INDEPENDENT VERIFICATION = PASS")
print("UNKNOWN DISCLOSURE = PASS")
print("SCOPE CONTROL = PASS")
print("PRODUCTION = LOCKED")
PY
