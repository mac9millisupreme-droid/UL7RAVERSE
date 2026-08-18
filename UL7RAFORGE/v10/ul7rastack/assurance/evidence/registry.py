import json
import hashlib
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "assurance/evidence"

REQUIRED = {
    "approved_cryptography": BASE / "crypto",
    "key_lifecycle": BASE / "keys",
    "hardware_backed_keys": BASE / "hardware",
    "one_way_enforcement": BASE / "network",
    "reproducible_builds": BASE / "build",
    "independent_verification": BASE / "independent",
}

ATTESTATIONS = {
    "approved_cryptography": "approved_cryptography.attestation.json",
    "key_lifecycle": "key_lifecycle.attestation.json",
    "hardware_backed_keys": "hardware_backed_keys.attestation.json",
    "one_way_enforcement": "one_way_enforcement.attestation.json",
    "reproducible_builds": "reproducible_builds.attestation.json",
    "independent_verification": "independent_verification.attestation.json",
}

records = {}

for control, directory in REQUIRED.items():
    files = [
        p for p in directory.rglob("*")
        if p.is_file()
        and not p.name.endswith(".attestation.json")
    ]

    attestation = BASE / ATTESTATIONS[control]

    valid_attestation = False
    attestation_reason = "MISSING"

    if attestation.is_file():
        try:
            data = json.loads(attestation.read_text())

            valid_attestation = (
                data.get("control") == control
                and data.get("status") == "ATTESTED"
                and bool(data.get("sha256"))
            )

            attestation_reason = (
                "VALID" if valid_attestation else "INVALID"
            )
        except Exception:
            attestation_reason = "INVALID"

    records[control] = {
        "evidence_files": len(files),
        "attestation": attestation_reason,
        "status": (
            "EVIDENCE_PRESENT"
            if files and valid_attestation
            else "UNVERIFIED"
        )
    }

unverified = [
    control
    for control, record in records.items()
    if record["status"] != "EVIDENCE_PRESENT"
]

result = {
    "system": "UL7RAVERSE",
    "profile": "HIGH_ASSURANCE",
    "controls": records,
    "unverified": unverified,
    "status": (
        "ELIGIBLE_FOR_EXTERNAL_ASSESSMENT"
        if not unverified
        else "BLOCKED"
    ),
    "production": "LOCKED",
    "certification_claim": False,
    "rule": "EVIDENCE_AND_ATTESTATION_REQUIRED",
    "timestamp": time.time()
}

canonical = json.dumps(result, sort_keys=True)
result["evidence_hash"] = hashlib.sha256(
    canonical.encode()
).hexdigest()

out = ROOT / "assurance/state/evidence_registry.json"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(result, indent=2))

print(json.dumps(result, indent=2))
