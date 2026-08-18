import json
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

required = [
    "orchestrator",
    "coding_swarm",
    "sandbox",
    "policy_engine",
    "verification_engine",
    "provenance_engine",
    "evidence_ledger",
    "purple_team",
    "rollback_engine"
]

manifest = json.loads((ROOT / "state" / "build.json").read_text())

assert manifest["version"] == "V0.6"
assert manifest["factory"] == "UL7RAFORGE"
assert manifest["production_promotion"] == "LOCKED"

for component in required:
    assert component in manifest["components"], (
        f"MISSING_COMPONENT:{component}"
    )

reconstructed = {
    "version": manifest["version"],
    "factory": manifest["factory"],
    "components": manifest["components"],
    "production_promotion": manifest["production_promotion"],
    "timestamp": manifest["timestamp"]
}

expected = hashlib.sha256(
    json.dumps(reconstructed, sort_keys=True).encode()
).hexdigest()

assert expected == manifest["build_hash"], "BUILD_HASH_MISMATCH"

evidence = ROOT / "evidence" / "build.jsonl"
assert evidence.exists()
assert evidence.stat().st_size > 0

print("V0.6 TEST = PASS")
print("COMPONENTS = 9")
print("MANIFEST = VALID")
print("HASH = VALID")
print("EVIDENCE = PRESENT")
print("PROMOTION = LOCKED")
