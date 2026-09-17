from typing import Dict, Any

def validate_race_state(race_state: Dict[str, Any]) -> Dict[str, Any]:
    required = ["race_id", "track", "surface", "distance", "race_start_timestamp"]
    missing = [k for k in required if k not in race_state or race_state[k] is None]
    if missing:
        return {"status": "FAIL", "missing_fields": missing}
    return {"status": "PASS", "missing_fields": []}
