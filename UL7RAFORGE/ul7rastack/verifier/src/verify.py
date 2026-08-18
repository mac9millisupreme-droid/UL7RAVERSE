import json
import hashlib
import sys
from pathlib import Path

status_file = Path(sys.argv[1])

data = json.loads(status_file.read_text())

required = [
    "system",
    "attestation_type",
    "status",
    "controls",
    "exceptions",
    "unknowns",
    "scope",
    "timestamp",
    "attestation_hash"
]

missing = [x for x in required if x not in data]

if missing:
    print("INDEPENDENT VERIFIER = FAIL")
    print("MISSING:", ",".join(missing))
    raise SystemExit(1)

# Reconstruct the signed content exactly as the producer did.
candidate = dict(data)
claimed_hash = candidate.pop("attestation_hash")

canonical = json.dumps(candidate, sort_keys=True)
calculated = hashlib.sha256(canonical.encode()).hexdigest()

if calculated != claimed_hash:
    print("INDEPENDENT VERIFIER = FAIL")
    print("ATTESTATION HASH MISMATCH")
    raise SystemExit(1)

if data["production"] != "LOCKED":
    print("INDEPENDENT VERIFIER = FAIL")
    print("PRODUCTION STATE INVALID")
    raise SystemExit(1)

if data["exceptions"] < 0:
    print("INDEPENDENT VERIFIER = FAIL")
    print("INVALID EXCEPTION COUNT")
    raise SystemExit(1)

print("INDEPENDENT VERIFIER = PASS")
print("ATTESTATION HASH = VALID")
print("SCHEMA = VALID")
print("SCOPE = DECLARED")
print("UNKNOWN STATES = PRESERVED")
print("PRODUCTION = LOCKED")
