import json
import hashlib
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

CONTROLS = {
    "approved_cryptography": False,
    "key_lifecycle": False,
    "hardware_backed_keys": False,
    "zero_trust": True,
    "least_privilege": True,
    "microsegmentation": True,
    "ghost_isolation": True,
    "one_way_enforcement": False,
    "continuous_monitoring": True,
    "purple_team": True,
    "tamper_evident_evidence": True,
    "automatic_containment": True,
    "canadian_residency": True,
    "egress_default_deny": True,
    "reproducible_builds": False,
    "supply_chain_provenance": True,
    "independent_verification": False,
    "tested_rollback": True,
    "fail_closed_production": True
}

UNKNOWN = [
    name for name, passed in CONTROLS.items()
    if not passed
]

passed = sum(CONTROLS.values())
total = len(CONTROLS)

result = {
    "system": "UL7RAVERSE",
    "profile": "HIGH_ASSURANCE",
    "controls_passed": passed,
    "controls_total": total,
    "unknown_or_unverified": UNKNOWN,
    "status": "BLOCKED" if UNKNOWN else "ELIGIBLE_FOR_EXTERNAL_ASSESSMENT",
    "production": "LOCKED",
    "certification_claim": False,
    "certification_statement":
        "NO GOVERNMENT_OR_MILITARY_CERTIFICATION_CLAIM",
    "timestamp": time.time()
}

canonical = json.dumps(result, sort_keys=True)
result["evidence_hash"] = hashlib.sha256(
    canonical.encode()
).hexdigest()

out = ROOT / "assurance/state/high_assurance.json"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(result, indent=2))

print(json.dumps(result, indent=2))
