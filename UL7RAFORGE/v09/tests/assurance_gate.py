import json
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

checks = {
    "SECURITY": ROOT / "security",
    "PROVENANCE": ROOT / "provenance",
    "TRINITY": ROOT / "trinity",
    "PURPLE": ROOT / "purple",
    "ROLLBACK": ROOT / "rollback",
}

results = {}

for name, path in checks.items():
    results[name] = {
        "status": "READY" if path.exists() else "BLOCKED",
        "evidence_path": str(path)
    }

state = {
    "candidate": "UL7RAFORGE_V0.9",
    "gate": "ASSURANCE",
    "results": results,
    "promotion": "BLOCKED",
    "timestamp": time.time()
}

(ROOT / "state" / "assurance_gate.json").write_text(
    json.dumps(state, indent=2)
)

print(json.dumps(state, indent=2))
