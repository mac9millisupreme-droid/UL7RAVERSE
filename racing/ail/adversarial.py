from typing import List, Dict, Any
from .provenance import validate_provenance
from .temporal import check_temporal_integrity

def run_adversarial_checks(pred_input,
                           feature_timestamps: List[Dict[str, str]],
                           race_start_timestamp: str,
                           duplicate_horse_ids: List[str] = None) -> List[str]:
    violations = []
    prov = validate_provenance(pred_input)
    if prov["status"] == "FAIL":
        violations.append(f"Provenance invalid: {prov['missing_fields']}")

    ti = check_temporal_integrity(pred_input.decision_timestamp,
                                  feature_timestamps,
                                  race_start_timestamp)
    if ti["status"] == "FAIL":
        violations.append(f"Temporal violation: {ti['violations']}")

    if pred_input.odds is not None and pred_input.odds <= 1.0:
        violations.append("Invalid odds (<=1) in prediction")

    if duplicate_horse_ids:
        if len(duplicate_horse_ids) != len(set(duplicate_horse_ids)):
            violations.append("Duplicate horse_id in race")

    return violations
