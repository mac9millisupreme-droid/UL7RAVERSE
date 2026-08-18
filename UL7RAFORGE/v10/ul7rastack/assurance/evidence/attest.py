import hashlib
import json
import sys
import time
from pathlib import Path

if len(sys.argv) != 3:
    print("usage: attest.py <control> <evidence_file>")
    raise SystemExit(2)

control = sys.argv[1]
path = Path(sys.argv[2])

if not path.is_file():
    raise SystemExit(f"EVIDENCE NOT FOUND: {path}")

digest = hashlib.sha256(path.read_bytes()).hexdigest()

record = {
    "system": "UL7RAVERSE",
    "control": control,
    "evidence_file": str(path),
    "sha256": digest,
    "status": "ATTESTED",
    "timestamp": time.time(),
    "production": "LOCKED"
}

out = Path("v10/ul7rastack/assurance/evidence") / f"{control}.attestation.json"
out.write_text(json.dumps(record, indent=2))

print(json.dumps(record, indent=2))
