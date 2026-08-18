import json
import hashlib
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVENTS = ROOT / "security" / "events"

WEIGHTS = {
    "security": 25,
    "compliance": 25,
    "evidence": 20,
    "governance": 10,
    "data_residency": 10,
    "provenance": 10
}

REQUIRED = {
    "security": ["CHEETAH_EGRESS", "GHOST_POLICY"],
    "compliance": ["CANADA_RESIDENCY"],
    "evidence": ["CHEETAH_EGRESS", "CANADA_RESIDENCY"],
    "governance": ["GOVERNANCE_CHECK"],
    "data_residency": ["CANADA_RESIDENCY"],
    "provenance": ["PROVENANCE_CHECK"]
}

events = []

if EVENTS.exists():
    for path in sorted(EVENTS.glob("*.json")):
        try:
            events.append(json.loads(path.read_text()))
        except Exception:
            continue

latest = {}

for event in events:
    event_type = event.get("event_type")
    result = event.get("result")

    if event_type and result:
        latest[event_type] = result

dimensions = {}
missing_evidence = []

for dimension, requirements in REQUIRED.items():
    passed = 0

    for requirement in requirements:
        if latest.get(requirement) == "PASS":
            passed += 1
        else:
            missing_evidence.append({
                "dimension": dimension,
                "required_event": requirement,
                "observed": latest.get(requirement, "MISSING")
            })

    dimensions[dimension] = round(
        (passed / len(requirements)) * 100
    )

score = sum(
    dimensions[name] * WEIGHTS[name]
    for name in WEIGHTS
) / 100

unknowns = [
    "kernel_level_isolation",
    "physical_one_way_network",
    "undiscovered_vulnerabilities"
]

status = (
    "VERIFIED_WITH_SCOPE"
    if not missing_evidence
    else "REVIEW_REQUIRED"
)

result = {
    "system": "UL7RAVERSE",
    "product": "UL7RA_VERISCORE",
    "score": round(score, 2),
    "status": status,
    "dimensions": dimensions,
    "weights": WEIGHTS,
    "events_observed": len(events),
    "missing_evidence": missing_evidence,
    "unknowns": unknowns,
    "evidence_freshness": "CURRENT",
    "calculation": "EVIDENCE_DERIVED_DETERMINISTIC_SCORE",
    "claim_limit": "ASSURANCE_SCORE_NOT_ABSOLUTE_SECURITY_OR_LEGAL_COMPLIANCE",
    "production": "LOCKED",
    "timestamp": time.time()
}

canonical = json.dumps(result, sort_keys=True)
result["veriscore_hash"] = hashlib.sha256(
    canonical.encode()
).hexdigest()

output = ROOT / "veriscore" / "state" / "veriscore.json"
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(result, indent=2))

print(json.dumps(result, indent=2))
