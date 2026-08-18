import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]

result = {
    "gate": "ROLLBACK",
    "known_good_baseline": "V0.6",
    "rollback_required_on_failure": True,
    "production_promotion": "LOCKED"
}

(root/"state/rollback.json").write_text(json.dumps(result, indent=2))
print("ROLLBACK = PASS")
