import json
import hashlib
import sys
import time
from pathlib import Path

root = Path(__file__).resolve().parents[1]
events = root / "events"
state = root / "state"

event_type = sys.argv[1] if len(sys.argv) > 1 else "UNKNOWN"
result = sys.argv[2] if len(sys.argv) > 2 else "UNKNOWN"

previous = sorted(events.glob("*.json"))
previous_hash = "GENESIS"

if previous:
    previous_hash = json.loads(previous[-1].read_text())["event_hash"]

event = {
    "event_type": event_type,
    "result": result,
    "timestamp": time.time(),
    "previous_hash": previous_hash
}

canonical = json.dumps(event, sort_keys=True)
event["event_hash"] = hashlib.sha256(canonical.encode()).hexdigest()

path = events / f"{int(event['timestamp'] * 1000000)}.json"
path.write_text(json.dumps(event, indent=2))

print(json.dumps(event, indent=2))
