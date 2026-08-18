import json
import hashlib
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]

REQUIRED = {
    "high_assurance": ROOT / "assurance/state/high_assurance.json",
    "evidence_registry": ROOT / "assurance/state/evidence_registry.json",
    "veriscore": ROOT / "veriscore/state/veriscore.json",
}

def load(path):
    if not path.is_file():
        return None
    return json.loads(path.read_text())

checks = {}
blocking = []

for name, path in REQUIRED.items():
    data = load(path)

    if data is None:
        checks[name] = "MISSING"
        blocking.append(name)
        continue

    checks[name] = "PRESENT"

    if data.get("production") == "LOCKED":
        blocking.append(f"{name}:production_locked")

    if data.get("certification_claim") is False:
        pass

    if data.get("unknown_or_unverified"):
        blocking.append(f"{name}:unknown_or_unverified")

    if data.get("unverified"):
        blocking.append(f"{name}:unverified")

required_states = {
    "high_assurance",
    "evidence_registry",
    "veriscore",
}

for name in required_states:
    if checks.get(name) != "PRESENT":
        blocking.append(f"{name}:missing")

status = "BLOCKED" if blocking else "ELIGIBLE_FOR_RELEASE_GATE"

result = {
    "system": "UL7RAVERSE",
    "stage": "PRODUCTION_READINESS",
    "status": status,
    "checks": checks,
    "blocking_conditions": sorted(set(blocking)),
    "rule": "UNVERIFIED_NEVER_EQUALS_PASS",
    "certification_claim": False,
    "production": "LOCKED" if blocking else "RELEASE_GATE_PENDING",
    "timestamp": datetime.now(timezone.utc).isoformat(),
}

canonical = json.dumps(
    result,
    sort_keys=True,
    separators=(",", ":"),
).encode()

result["evidence_hash"] = hashlib.sha256(canonical).hexdigest()

print(json.dumps(result, indent=2))
