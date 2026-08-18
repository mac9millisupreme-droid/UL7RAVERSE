#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import json
import platform
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT_DIR = ROOT / "assurance/snapshots"

STATE_FILES = {
    "high_assurance": ROOT / "assurance/state/high_assurance.json",
    "evidence_registry": ROOT / "assurance/state/evidence_registry.json",
    "veriscore": ROOT / "veriscore/state/veriscore.json",
}

TESTS = [
    ROOT / "tests/high_assurance_regression.sh",
    ROOT / "tests/veriscore_regression.sh",
]

def sha256_file(path: Path) -> str | None:
    if not path.is_file():
        return None
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def load_json(path: Path):
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text())
    except Exception as exc:
        return {"_error": str(exc)}

def run_command(command):
    try:
        p = subprocess.run(
            command,
            cwd=ROOT,
            text=True,
            capture_output=True,
            timeout=300,
        )
        return {
            "command": command,
            "returncode": p.returncode,
            "stdout": p.stdout[-12000:],
            "stderr": p.stderr[-12000:],
            "status": "PASS" if p.returncode == 0 else "FAIL",
        }
    except Exception as exc:
        return {
            "command": command,
            "status": "ERROR",
            "error": str(exc),
        }

def main():
    now = datetime.now(timezone.utc).isoformat()

    states = {}
    blocking = []

    for name, path in STATE_FILES.items():
        data = load_json(path)

        states[name] = {
            "path": str(path.relative_to(ROOT)),
            "exists": path.is_file(),
            "sha256": sha256_file(path),
            "data": data,
        }

        if data is None:
            blocking.append(f"{name}:MISSING")
            continue

        if data.get("production") == "LOCKED":
            blocking.append(f"{name}:PRODUCTION_LOCKED")

        for key in ("unverified", "unknown_or_unverified"):
            values = data.get(key, [])
            if values:
                blocking.append(f"{name}:{key}={len(values)}")

    test_results = []

    for test in TESTS:
        if test.is_file():
            test_results.append(
                run_command(["bash", str(test)])
            )
        else:
            test_results.append({
                "command": str(test.relative_to(ROOT)),
                "status": "MISSING",
            })
            blocking.append(
                f"TEST_MISSING:{test.relative_to(ROOT)}"
            )

    high = states["high_assurance"]["data"] or {}
    evidence = states["evidence_registry"]["data"] or {}
    veri = states["veriscore"]["data"] or {}

    snapshot = {
        "system": "UL7RAVERSE",
        "factory": "UL7RAFORGE",
        "snapshot_type": "AUTHORITATIVE_RUNTIME_READINESS",
        "timestamp": now,

        "environment": {
            "platform": platform.platform(),
            "python": platform.python_version(),
            "machine": platform.machine(),
        },

        "readiness": {
            "high_assurance_controls_passed":
                high.get("controls_passed"),
            "high_assurance_controls_total":
                high.get("controls_total"),
            "high_assurance_unverified":
                high.get("unknown_or_unverified", []),

            "evidence_unverified":
                evidence.get("unverified", []),

            "veriscore":
                veri.get("veriscore"),

            "veriscore_claim_limit":
                veri.get(
                    "claim_limit",
                    "ASSURANCE_SCORE_NOT_ABSOLUTE_SECURITY_OR_LEGAL_COMPLIANCE"
                ),

            "production": "LOCKED",
            "certification_claim": False,
            "blocking_conditions": sorted(set(blocking)),
        },

        "state_files": states,
        "tests": test_results,

        "rules": [
            "UNVERIFIED_NEVER_EQUALS_PASS",
            "UNKNOWN_REMAINS_UNKNOWN",
            "CERTIFICATION_REQUIRES_AUTHORITY",
            "PRODUCTION_REQUIRES_RELEASE_GATE",
            "EVIDENCE_REQUIRED_FOR_VERIFICATION",
        ],
    }

    payload = json.dumps(
        snapshot,
        indent=2,
        sort_keys=True,
    )

    snapshot_hash = hashlib.sha256(
        payload.encode()
    ).hexdigest()

    snapshot["snapshot_hash"] = snapshot_hash

    output = SNAPSHOT_DIR / "current_system_snapshot.json"
    output.write_text(
        json.dumps(snapshot, indent=2, sort_keys=True)
    )

    print(json.dumps({
        "system": "UL7RAVERSE",
        "snapshot": str(output.relative_to(ROOT)),
        "status": (
            "BLOCKED"
            if blocking
            else "ELIGIBLE_FOR_RELEASE_GATE"
        ),
        "production": "LOCKED",
        "certification_claim": False,
        "blocking_conditions": sorted(set(blocking)),
        "snapshot_hash": snapshot_hash,
    }, indent=2))

if __name__ == "__main__":
    main()
