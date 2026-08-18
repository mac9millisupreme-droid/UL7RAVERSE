import json
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
state = json.loads((ROOT / "state" / "candidate.json").read_text())

required = [
    "security",
    "provenance",
    "trinity",
    "purple_team",
    "rollback",
    "oracl3",
    "node9",
    "coding_swarm"
]

assert state["candidate"] == "UL7RAFORGE_V0.9"
assert state["status"] == "CANDIDATE"
assert state["promotion"] == "BLOCKED"

for item in required:
    assert state["capabilities"][item] == "REQUIRED"

base = {
    "candidate": state["candidate"],
    "status": state["status"],
    "source": state["source"],
    "bundled_generations": state["bundled_generations"],
    "capabilities": state["capabilities"],
    "promotion": state["promotion"],
    "timestamp": state["timestamp"]
}

expected = hashlib.sha256(
    json.dumps(base, sort_keys=True).encode()
).hexdigest()

assert expected == state["candidate_hash"]

print("V0.9 CANDIDATE INTEGRITY = PASS")
print("CAPABILITY GRAPH = PASS")
print("HASH INTEGRITY = PASS")
print("PROMOTION = BLOCKED")
print("NEXT = SECURITY / PURPLE / TRINITY VERIFICATION")
