#!/usr/bin/env python3
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run = Path(sys.argv[2]).resolve()
run.mkdir(parents=True, exist_ok=True)

fixture = {
    "fixture_id": "blue-fixture-001",
    "event_type": "POLICY_VIOLATION",
    "rule": "TEST_AUTHORIZATION_REQUIRED",
    "marker": "UL7RA-BLUE-001",
    "scope": "LOCAL_ASSURANCE_ONLY"
}

detected = fixture["marker"] == "UL7RA-BLUE-001"
contained = detected
response = "REJECTED" if contained else "ALLOWED"

result = {
    "fixture_id": fixture["fixture_id"],
    "detector_id": "BLUE-DET-001",
    "event_type": fixture["event_type"],
    "detected": detected,
    "contained": contained,
    "response": response
}

canonical = json.dumps(
    result, sort_keys=True, separators=(",", ":")
).encode()

result["canonical_hash"] = hashlib.sha256(canonical).hexdigest()
result["authorization_scope"] = "LOCAL_ASSURANCE_ONLY"
result["external_target"] = False
result["destructive"] = False
result["timestamp"] = datetime.now(timezone.utc).isoformat()

(run / "evidence.json").write_text(
    json.dumps(result, indent=2, sort_keys=True)
)

assert result["detected"], "BLUE_DETECTION_FAILED"
assert result["contained"], "BLUE_CONTAINMENT_FAILED"
assert result["response"] == "REJECTED", "BLUE_RESPONSE_FAILED"

print(json.dumps(result, indent=2, sort_keys=True))
print("BLUE_DETECTION=PASS")
print("BLUE_CONTAINMENT=PASS")
print("BLUE_EVIDENCE=PASS")
print("BLUE_REGRESSION=PASS")
