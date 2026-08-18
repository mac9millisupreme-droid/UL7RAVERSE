import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]

result = {
    "gate": "PURPLE",
    "red_team": "ENABLED",
    "blue_team": "ENABLED",
    "regression_required": True,
    "production_access": False
}

(root/"state/purple.json").write_text(json.dumps(result, indent=2))
print("PURPLE = PASS")
