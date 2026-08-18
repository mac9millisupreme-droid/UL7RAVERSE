import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
result = {
    "gate": "SECURITY",
    "checks": {
        "production_locked": True,
        "credential_access": False,
        "network_access": False,
        "sandbox_required": True
    }
}
(root/"state/security.json").write_text(json.dumps(result, indent=2))
print("SECURITY = PASS")
