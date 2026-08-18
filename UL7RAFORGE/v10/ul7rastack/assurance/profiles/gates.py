import json
import hashlib
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

GATES = {
    "approved_cryptography": {
        "status": "UNVERIFIED",
        "evidence_required": "approved_algorithm_inventory"
    },
    "key_lifecycle": {
        "status": "UNVERIFIED",
        "evidence_required": "key_generation_rotation_revocation_test"
    },
    "hardware_backed_keys": {
        "status": "UNVERIFIED",
        "evidence_required": "hardware_root_of_trust_attestation"
    },
    "one_way_enforcement": {
        "status": "UNVERIFIED",
        "evidence_required": "independent_network_enforcement_test"
    },
    "reproducible_builds": {
        "status": "UNVERIFIED",
        "evidence_required": "independent_reproducible_build"
    },
    "independent_verification": {
        "status": "UNVERIFIED",
        "evidence_required": "independent_security_assessment"
    }
}

result = {
    "system": "UL7RAVERSE",
    "profile": "HIGH_ASSURANCE",
    "gate_count": len(GATES),
    "gates": GATES,
    "status": "BLOCKED",
    "production": "LOCKED",
    "certification_claim": False,
    "rule": "UNVERIFIED_NEVER_EQUALS_PASS",
    "timestamp": time.time()
}

canonical = json.dumps(result, sort_keys=True)
result["evidence_hash"] = hashlib.sha256(
    canonical.encode()
).hexdigest()

out = ROOT / "assurance/state/high_assurance_gates.json"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(result, indent=2))

print(json.dumps(result, indent=2))
