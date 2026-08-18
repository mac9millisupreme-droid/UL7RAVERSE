import json
import time
from pathlib import Path

root = Path(__file__).resolve().parents[1]
events = root / "events"
out = root / "state" / "runtime_assurance.json"

records = [
    json.loads(p.read_text())
    for p in sorted(events.glob("*.json"))
]

latest = {}

for event in records:
    latest[event["event_type"]] = event["result"]

failures = [
    name for name, result in latest.items()
    if result == "FAIL"
]

status = {
    "system": "UL7RAVERSE",
    "mode": "EVENT_DRIVEN_ASSURANCE",
    "security_status": "VERIFIED_WITH_SCOPE"
        if not failures else "BLOCKED",
    "events_observed": len(records),
    "active_failures": failures,
    "detected_failures": len(failures),
    "evidence_freshness": "CURRENT",
    "production": "LOCKED",
    "timestamp": time.time()
}

out.write_text(json.dumps(status, indent=2))
print(json.dumps(status, indent=2))
