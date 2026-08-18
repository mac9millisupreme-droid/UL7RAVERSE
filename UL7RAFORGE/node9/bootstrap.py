import json
import hashlib
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parent
EXPERTS = [
    "ARCHITECT",
    "ENGINEER",
    "SECURITY",
    "VERIFICATION",
    "COMPLIANCE",
    "NETWORK",
    "INTELLIGENCE",
    "OPERATIONS",
    "EVOLUTION"
]

for name in EXPERTS:
    p = ROOT / "experts" / name.lower()
    p.mkdir(parents=True, exist_ok=True)

    config = {
        "expert": name,
        "status": "INITIALIZED",
        "authority": "PROPOSE_ONLY",
        "sub_experts": [],
        "requires_trinity_verification": True
    }

    (p / "config.json").write_text(
        json.dumps(config, indent=2)
    )

def sha(data):
    return hashlib.sha256(
        json.dumps(data, sort_keys=True).encode()
    ).hexdigest()

state = {
    "system": "NODE9",
    "version": "0.1",
    "status": "INITIALIZED",
    "experts": EXPERTS,
    "architecture": {
        "trinity_core": True,
        "ul7raforge": True,
        "ul7rabridge": True,
        "perpetual_purple_team": True
    },
    "timestamp": datetime.now(timezone.utc).isoformat()
}

state["integrity_hash"] = sha(state)

(ROOT / "state" / "node9.json").write_text(
    json.dumps(state, indent=2)
)

evidence = {
    "event": "NODE9_BOOTSTRAP",
    "state_hash": state["integrity_hash"],
    "experts_initialized": len(EXPERTS),
    "verification": "PENDING"
}

with (ROOT / "evidence" / "bootstrap.jsonl").open("a") as f:
    f.write(json.dumps(evidence) + "\n")

print(json.dumps({
    "NODE9": "INITIALIZED",
    "EXPERTS": len(EXPERTS),
    "TRINITY": "CONNECTED",
    "PURPLE_TEAM": "REQUIRED",
    "VERIFICATION": "PENDING"
}, indent=2))
