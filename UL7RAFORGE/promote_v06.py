import json, hashlib, time
from pathlib import Path

ROOT = Path(__file__).resolve().parent

checks = {
    "V0.1_KERNEL": [
        "kernel/state.json",
        "kernel/health.py",
        "config/factory.json",
    ],
    "V0.2_TRINITY": [
        "trinity/core.py",
        "trinity/state/current.json",
    ],
    "V0.3_NODE9": [
        "node9/bootstrap.py",
        "node9/state/node9.json",
    ],
    "V0.4_PURPLE": [
        "purple",
    ],
    "V0.5_ORACLE": [
        "oracl3/oracle/engine.py",
        "oracl3/state/current.json",
    ],
}

results = {}
all_pass = True

for version, paths in checks.items():
    missing = []
    for p in paths:
        if not (ROOT / p).exists():
            missing.append(p)

    passed = not missing
    results[version] = {
        "status": "PASS" if passed else "BLOCKED",
        "missing": missing
    }

    if not passed:
        all_pass = False

# V0.6 prerequisites
v06 = {
    "status": "VERIFIED" if all_pass else "BLOCKED",
    "previous_generations": results,
    "required_gates": [
        "BUILD",
        "TEST",
        "SECURITY",
        "PROVENANCE",
        "TRINITY",
        "PURPLE",
        "ROLLBACK"
    ],
    "timestamp": time.time()
}

v06["audit_hash"] = hashlib.sha256(
    json.dumps(v06, sort_keys=True).encode()
).hexdigest()

(ROOT / "state").mkdir(exist_ok=True)
(ROOT / "evidence").mkdir(exist_ok=True)

(ROOT / "state/v06_promotion.json").write_text(
    json.dumps(v06, indent=2)
)

with (ROOT / "evidence/promotion.jsonl").open("a") as f:
    f.write(json.dumps(v06) + "\n")

print(json.dumps(v06, indent=2))

if not all_pass:
    raise SystemExit(
        "\nV0.6 PROMOTION BLOCKED — missing prerequisites."
    )

print("\nV0.6 PROMOTION ELIGIBLE.")
