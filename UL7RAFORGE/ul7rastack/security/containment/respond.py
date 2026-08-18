import json
import time
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
assurance = ROOT / "state/runtime_assurance.json"
state_file = ROOT / "containment/state.json"
evidence_dir = ROOT / "evidence"

state = json.loads(assurance.read_text())

if state["detected_failures"] > 0:
    action = {
        "status": "CONTAINED",
        "actions": [
            "BLOCK_TRAFFIC",
            "ISOLATE_WORKLOAD",
            "PRESERVE_EVIDENCE",
            "REVOKE_ATTESTATION",
            "REQUIRE_REVERIFICATION"
        ],
        "reason": "SECURITY_FAILURE",
        "timestamp": time.time()
    }
else:
    action = {
        "status": "NO_CONTAINMENT_REQUIRED",
        "actions": [],
        "reason": "NO_DETECTED_FAILURES",
        "timestamp": time.time()
    }

canonical = json.dumps(action, sort_keys=True)
action["evidence_hash"] = hashlib.sha256(
    canonical.encode()
).hexdigest()

state_file.parent.mkdir(parents=True, exist_ok=True)
evidence_dir.mkdir(parents=True, exist_ok=True)

state_file.write_text(json.dumps(action, indent=2))
(evidence_dir / "latest_containment.json").write_text(
    json.dumps(action, indent=2)
)

print(json.dumps(action, indent=2))
