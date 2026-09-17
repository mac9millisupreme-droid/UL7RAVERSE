from datetime import datetime
from typing import List, Dict, Any

def check_temporal_integrity(decision_timestamp: str,
                             feature_timestamps: List[Dict[str, str]],
                             race_start_timestamp: str) -> Dict[str, Any]:
    violations = []
    try:
        dt_decision = datetime.fromisoformat(decision_timestamp)
    except Exception as e:
        return {"status": "FAIL", "violations": [f"Invalid decision timestamp: {e}"]}

    try:
        dt_race = datetime.fromisoformat(race_start_timestamp)
        if dt_race <= dt_decision:
            violations.append("race_start_timestamp <= decision_timestamp")
    except Exception as e:
        violations.append(f"Invalid race start timestamp: {e}")

    for feat in feature_timestamps:
        name = feat.get("name", "unnamed")
        ts = feat.get("timestamp")
        if not ts:
            violations.append(f"Feature '{name}' missing timestamp")
            continue
        try:
            dt_feat = datetime.fromisoformat(ts)
            if dt_feat > dt_decision:
                violations.append(f"Feature '{name}' observed after decision")
        except Exception as e:
            violations.append(f"Feature '{name}' invalid timestamp: {e}")

    return {"status": "PASS" if not violations else "FAIL", "violations": violations}
