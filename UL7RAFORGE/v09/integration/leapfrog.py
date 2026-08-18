import json
import hashlib
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

capabilities = {
    "security": "REQUIRED",
    "provenance": "REQUIRED",
    "trinity": "REQUIRED",
    "purple_team": "REQUIRED",
    "rollback": "REQUIRED",
    "oracl3": "REQUIRED",
    "node9": "REQUIRED",
    "coding_swarm": "REQUIRED"
}

state = {
    "candidate": "UL7RAFORGE_V0.9",
    "status": "CANDIDATE",
    "source": "V0.6",
    "bundled_generations": ["V0.7", "V0.8", "V0.9"],
    "capabilities": capabilities,
    "promotion": "BLOCKED",
    "timestamp": time.time()
}

state["candidate_hash"] = hashlib.sha256(
    json.dumps(state, sort_keys=True).encode()
).hexdigest()

(ROOT / "state" / "candidate.json").write_text(
    json.dumps(state, indent=2)
)

with (ROOT / "evidence" / "leapfrog.jsonl").open("a") as f:
    f.write(json.dumps({
        "event": "V0.9_LEAPFROG_CANDIDATE",
        "candidate_hash": state["candidate_hash"],
        "status": "CANDIDATE",
        "promotion": "BLOCKED",
        "timestamp": state["timestamp"]
    }) + "\n")

print(json.dumps({
    "CANDIDATE": state["candidate"],
    "STATUS": state["status"],
    "BUNDLED": state["bundled_generations"],
    "CAPABILITIES": len(capabilities),
    "PROMOTION": state["promotion"],
    "HASH": state["candidate_hash"]
}, indent=2))
