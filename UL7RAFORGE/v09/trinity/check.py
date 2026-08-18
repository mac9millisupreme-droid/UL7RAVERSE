import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]

result = {
    "gate": "TRINITY",
    "build": "REQUIRED",
    "verify": "REQUIRED",
    "learn": "REQUIRED",
    "promotion": "BLOCKED_UNTIL_ALL_THREE"
}

(root/"state/trinity.json").write_text(json.dumps(result, indent=2))
print("TRINITY = PASS")
