#!/usr/bin/env python3

import hashlib
import json
import sys
import time
from pathlib import Path

ASSURANCE_ROOT = Path(__file__).resolve().parents[1]
EVIDENCE_ROOT = ASSURANCE_ROOT / "evidence"

if len(sys.argv) != 3:
    print("usage: attest.py <control> <evidence_file>")
    raise SystemExit(2)

control = sys.argv[1]
supplied = Path(sys.argv[2])

if supplied.is_absolute():
    path = supplied.resolve()
else:
    candidates = [
        (Path.cwd() / supplied).resolve(),
        (EVIDENCE_ROOT / supplied).resolve(),
    ]

    path = next(
        (candidate for candidate in candidates if candidate.is_file()),
        candidates[0]
    )

if not path.is_file():
    raise SystemExit(f"EVIDENCE_NOT_FOUND: {path}")

digest = hashlib.sha256(path.read_bytes()).hexdigest()

# Store the path relative to the ASSURANCE directory.
try:
    relative_evidence = path.relative_to(ASSURANCE_ROOT)
except ValueError:
    raise SystemExit(
        f"EVIDENCE_OUTSIDE_ASSURANCE_ROOT: {path}"
    )

record = {
    "system": "UL7RAVERSE",
    "control": control,
    "evidence_file": str(relative_evidence),
    "sha256": digest,
    "status": "ATTESTED",
    "timestamp": time.time(),
    "production": "LOCKED"
}

out = EVIDENCE_ROOT / f"{control}.attestation.json"
out.parent.mkdir(parents=True, exist_ok=True)

out.write_text(
    json.dumps(record, indent=2, sort_keys=True) + "\n"
)

print(json.dumps(record, indent=2, sort_keys=True))
