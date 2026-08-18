#!/data/data/com.termux/files/usr/bin/bash
set -eu

python - <<'PY'
import json

p = "v10/ul7rastack/veriscore/state/veriscore.json"
d = json.load(open(p))

assert d["product"] == "UL7RA_VERISCORE"
assert 0 <= d["score"] <= 100
assert d["evidence_freshness"] == "CURRENT"
assert d["production"] == "LOCKED"
assert d["calculation"] == "EVENT_DERIVED_DETERMINISTIC_SCORE"
assert d["veriscore_hash"]

required = {
    "security",
    "compliance",
    "evidence",
    "governance",
    "data_residency",
    "provenance"
}

assert set(d["dimensions"]) == required
assert set(d["weights"]) == required
assert sum(d["weights"].values()) == 100
assert len(d["unknowns"]) > 0

print("VERISCORE CALCULATION = PASS")
print("EVENT DERIVATION = PASS")
print("WEIGHTS = PASS")
print("EVIDENCE FRESHNESS = PASS")
print("UNKNOWN DISCLOSURE = PASS")
print("HASH = PRESENT")
print("PRODUCTION = LOCKED")
print(f"VERISCORE = {d['score']}")
PY
