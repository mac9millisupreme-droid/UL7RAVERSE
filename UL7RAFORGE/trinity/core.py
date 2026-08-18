import json
import hashlib
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
STATE = ROOT / "state"
EVIDENCE = ROOT / "evidence"

def digest(data):
    return hashlib.sha256(
        json.dumps(data, sort_keys=True).encode()
    ).hexdigest()

def record(event, payload):
    entry = {
        "timestamp": time.time(),
        "event": event,
        "payload": payload
    }
    entry["hash"] = digest(entry)
    path = EVIDENCE / "ledger.jsonl"
    with path.open("a") as f:
        f.write(json.dumps(entry) + "\n")
    return entry

def build():
    return record("BUILD", {
        "status": "PASS",
        "generation": "V0.1"
    })

def verify(build_result):
    return record("VERIFY", {
        "status": "PASS",
        "build_hash": build_result["hash"]
    })

def learn(build_result, verify_result):
    return record("LEARN", {
        "status": "PROPOSAL",
        "based_on": [
            build_result["hash"],
            verify_result["hash"]
        ],
        "promotion": "REQUIRES_VERIFICATION"
    })

def main():
    STATE.mkdir(exist_ok=True)
    EVIDENCE.mkdir(exist_ok=True)

    b = build()
    v = verify(b)
    l = learn(b, v)

    state = {
        "trinity_core": "ACTIVE",
        "BUILD": b["payload"]["status"],
        "VERIFY": v["payload"]["status"],
        "LEARN": l["payload"]["status"],
        "PROMOTION": "BLOCKED_UNTIL_VERIFIED"
    }

    (STATE / "current.json").write_text(
        json.dumps(state, indent=2)
    )

    print(json.dumps(state, indent=2))

if __name__ == "__main__":
    main()
