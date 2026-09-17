from typing import Dict, Any

def validate_identity(race_id: str, horse_id: str) -> Dict[str, Any]:
    if not race_id or not horse_id:
        return {"status": "FAIL", "missing": ["race_id", "horse_id"]}
    return {"status": "PASS", "missing": []}
