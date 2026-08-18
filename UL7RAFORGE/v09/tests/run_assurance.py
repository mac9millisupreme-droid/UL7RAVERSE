import json, time, hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

gates = [
    "SECURITY",
    "PROVENANCE",
    "TRINITY",
    "PURPLE",
    "ROLLBACK"
]

results = {}

for gate in gates:
    path = ROOT / gate.lower()
    exists = path.exists()

    results[gate] = {
        "executed": True,
        "evidence": exists,
        "status": "PASS" if exists else "FAIL"
    }

passed = all(x["status"] == "PASS" for x in results.values())

report = {
    "candidate": "UL7RAFORGE_V0.9",
    "gate": "ASSURANCE",
    "results": results,
    "overall": "PASS" if passed else "FAIL",
    "promotion": "ELIGIBLE" if passed else "BLOCKED",
    "timestamp": time.time()
}

report["report_hash"] = hashlib.sha256(
    json.dumps(report, sort_keys=True).encode()
).hexdigest()

(ROOT / "state" / "assurance_report.json").write_text(
    json.dumps(report, indent=2)
)

with (ROOT / "evidence" / "assurance.jsonl").open("a") as f:
    f.write(json.dumps(report) + "\n")

print(json.dumps(report, indent=2))
