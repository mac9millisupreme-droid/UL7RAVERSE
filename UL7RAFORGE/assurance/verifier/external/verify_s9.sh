#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

NOW="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/v10/ul7rastack/assurance/runtime/verifier/external/$NOW"
mkdir -p "$OUT"

export ROOT OUT

python3 - <<'PY'
import hashlib
import json
import os
import platform
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(os.environ["ROOT"]).resolve()
out = Path(os.environ["OUT"]).resolve()

termux = (
    Path("/data/data/com.termux").exists()
    or bool(os.getenv("TERMUX_VERSION"))
)

required = {
    "VERIFIER_ENV_ID": os.getenv("VERIFIER_ENV_ID"),
    "VERIFIER_CREDENTIAL_DOMAIN": os.getenv("VERIFIER_CREDENTIAL_DOMAIN"),
    "NEUTRAL_STORE": os.getenv("NEUTRAL_STORE"),
    "VERIFIER_ATTESTATION_KEY_ID": os.getenv("VERIFIER_ATTESTATION_KEY_ID"),
}

missing = sorted(k for k, v in required.items() if not v)

record = {
    "schema_version": "EXTERNAL-S9-VERIFICATION-1",
    "component": "UL7RAFORGE_EXTERNAL_VERIFIER",
    "candidate": "S9",
    "baseline": "S8",
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "production": "LOCKED",
    "external_independence": "UNPROVEN",
    "independent_verification": "FAIL",
    "decision": "BLOCKED",
    "attestation_signed": False,
    "termux_detected": termux,
    "required_inputs_present": {
        k: bool(v) for k, v in required.items()
    },
    "reconciliation_evidence_hash":
        "47fc56691c8e7d78a1d6f6c27fb79c987ba36ec79f23faa3c6f7fec9fbbf2b57",
    "purple_evidence_hash":
        "67bf7d7a6234117026f518049807cfcc3040c48678e4d43e4856202f545b23b7",
}

if termux:
    record["reason"] = "LOCAL_TERMUX_CANNOT_ESTABLISH_EXTERNAL_INDEPENDENCE"
elif missing:
    record["reason"] = "MISSING_REQUIRED_VERIFIER_INPUT"
    record["missing"] = missing
else:
    record["reason"] = "EXTERNAL_BOOTSTRAP_INPUTS_PRESENT"

path = out / "verification_record.json"
path.write_text(
    json.dumps(record, indent=2, sort_keys=True) + "\n"
)

digest = hashlib.sha256(path.read_bytes()).hexdigest()

print("========================================")
print("UL7RAFORGE EXTERNAL VERIFIER")
print("========================================")
print("MODE=FAIL_CLOSED")
print("CANDIDATE=S9")
print("PRODUCTION=LOCKED")
print("EXTERNAL_INDEPENDENCE=UNPROVEN")
print("INDEPENDENT_VERIFICATION=FAIL")
print("DECISION=BLOCKED")
print(f"REASON={record['reason']}")
print(f"EVIDENCE={path}")
print(f"EVIDENCE_SHA256={digest}")
print("ATTESTATION_SIGNED=false")
print("========================================")

sys.exit(1)
PY
