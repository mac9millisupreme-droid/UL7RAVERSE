import json
import hashlib
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

frameworks = {
    "CA_PRIVACY_CONTROLS": {
        "jurisdiction": "CA",
        "status": "DEFINED",
        "evidence_required": True
    },
    "CA_SECURITY_CONTROLS": {
        "jurisdiction": "CA",
        "status": "DEFINED",
        "evidence_required": True
    },
    "CA_DATA_RESIDENCY_CONTROLS": {
        "jurisdiction": "CA",
        "status": "DEFINED",
        "evidence_required": True
    }
}

attestation = {
    "registry": "UL7RAVERSE_CA",
    "model": "CONTINUOUS_ASSURANCE",
    "jurisdiction": "CA",
    "frameworks": frameworks,
    "claim": "DEFINED_CONTROLS_ONLY",
    "evidence": "REQUIRED",
    "independent_verification": "REQUIRED",
    "unknowns": [
        "regulatory_interpretation",
        "controls_not_yet_mapped",
        "facts_outside_supplied_evidence"
    ],
    "status": "VERIFIED_WITH_SCOPE",
    "production": "LOCKED",
    "timestamp": time.time()
}

canonical = json.dumps(attestation, sort_keys=True)
attestation["registry_hash"] = hashlib.sha256(
    canonical.encode()
).hexdigest()

out = ROOT / "state/ca_registry_status.json"
out.write_text(json.dumps(attestation, indent=2))

print(json.dumps(attestation, indent=2))
