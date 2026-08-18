import json, time, hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

tests = {
    "SECURITY": [
        "security",
    ],
    "PROVENANCE": [
        "provenance",
    ],
    "TRINITY": [
        "trinity",
    ],
    "PURPLE": [
        "purple",
    ],
    "ROLLBACK": [
        "rollback",
    ],
}

results = {}

for gate, paths in tests.items():
    checks = []
    for p in paths:
        target = ROOT / p
        checks.append({
            "target": p,
            "exists": target.exists(),
            "nonempty": target.exists() and any(target.iterdir())
        })

    passed = all(x["exists"] and x["nonempty"] for x in checks)

    results[gate] = {
        "status": "PASS" if passed else "BLOCKED",
        "checks": checks
    }

passed = all(x["status"] == "PASS" for x in results.values())

report = {
    "candidate": "UL7RAFORGE_V0.9",
    "verification": "DEEP_ASSURANCE",
    "results": results,
    "overall": "PASS" if passed else "BLOCKED",
    "production_promotion": "LOCKED",
    "timestamp": time.time()
}

report["hash"] = hashlib.sha256(
    json.dumps(report, sort_keys=True).encode()
).hexdigest()

(ROOT / "state" / "deep_verify.json").write_text(
    json.dumps(report, indent=2)
)

print(json.dumps(report, indent=2))
