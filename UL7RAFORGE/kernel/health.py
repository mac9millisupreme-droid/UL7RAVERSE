import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
state = json.loads((root / "kernel/state.json").read_text())

required = [
    "factory", "state", "task_state", "artifact_state",
    "test_state", "security_state", "policy_state",
    "verification_state", "evidence_state", "release_state"
]

missing = [x for x in required if x not in state]

if missing:
    raise SystemExit("HEALTHCHECK_FAILED:" + ",".join(missing))

print(json.dumps({
    "factory": state["factory"],
    "state": state["state"],
    "healthcheck": "PASS"
}, indent=2))
