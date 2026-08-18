#!/usr/bin/env python3

import json
import hashlib
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "assurance/evidence"
STATE = ROOT / "assurance/state"
OUT = STATE / "assurance_gate_results.json"

GATES = {
    "approved_cryptography": {
        "path": EVIDENCE / "crypto",
        "required": "approved_algorithm_inventory",
    },
    "key_lifecycle": {
        "path": EVIDENCE / "keys",
        "required": "key_generation_rotation_revocation_test",
    },
    "hardware_backed_keys": {
        "path": EVIDENCE / "hardware",
        "required": "hardware_root_of_trust_attestation",
    },
    "one_way_enforcement": {
        "path": EVIDENCE / "network",
        "required": "independent_network_enforcement_test",
    },
    "reproducible_builds": {
        "path": EVIDENCE / "build",
        "required": "independent_reproducible_build",
    },
    "independent_verification": {
        "path": EVIDENCE / "independent",
        "required": "independent_security_assessment",
    },
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def inspect_gate(name, config):
    path = config["path"]

    files = sorted(
        p for p in path.rglob("*")
        if p.is_file()
        and not p.name.startswith(".")
    )

    # Evidence existence is NOT automatically verification.
    if not files:
        return {
            "status": "UNVERIFIED",
            "required": config["required"],
            "evidence_files": 0,
            "evidence_hashes": [],
        }

    hashes = [
        {
            "file": str(p.relative_to(ROOT)),
            "sha256": sha256(p),
        }
        for p in files
    ]

    # Evidence must explicitly identify itself as verified.
    verified = False

    for p in files:
        try:
            text = p.read_text(errors="strict")
        except Exception:
            continue

        if (
            "VERIFIED" in text
            and config["required"] in text
        ):
            verified = True
            break

    return {
        "status": "VERIFIED" if verified else "EVIDENCE_PRESENT",
        "required": config["required"],
        "evidence_files": len(files),
        "evidence_hashes": hashes,
    }


def main():
    results = {}

    for name, config in GATES.items():
        results[name] = inspect_gate(name, config)

    unverified = [
        name for name, result in results.items()
        if result["status"] != "VERIFIED"
    ]

    status = (
        "BLOCKED"
        if unverified
        else "ELIGIBLE_FOR_INDEPENDENT_ASSESSMENT"
    )

    result = {
        "system": "UL7RAVERSE",
        "profile": "HIGH_ASSURANCE",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "gates": results,
        "unverified": unverified,
        "status": status,
        "production": "LOCKED",
        "certification_claim": False,
        "rule": "EVIDENCE_REQUIRED_FOR_VERIFICATION",
    }

    canonical = json.dumps(
        result,
        sort_keys=True,
        separators=(",", ":"),
    ).encode()

    result["evidence_hash"] = hashlib.sha256(canonical).hexdigest()

    OUT.write_text(
        json.dumps(result, indent=2, sort_keys=True)
    )

    print(json.dumps(result, indent=2))

    return 0 if not unverified else 1


if __name__ == "__main__":
    sys.exit(main())
