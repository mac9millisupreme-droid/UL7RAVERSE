from typing import Dict, Any
from .schemas import PredictionInput, DataQuality

REQUIRED_FIELDS = ["race_id", "horse_id", "model_version", "data_timestamp", "decision_timestamp", "input_provenance"]

def validate_provenance(pred_input: PredictionInput) -> Dict[str, Any]:
    quality = pred_input.validate_fields()
    missing = [f for f in REQUIRED_FIELDS if quality.get(f) != DataQuality.PRESENT]
    if missing:
        return {"status": "FAIL", "missing_fields": missing}
    if not pred_input.input_provenance:
        return {"status": "FAIL", "missing_fields": ["input_provenance_empty"]}
    return {"status": "PASS", "missing_fields": []}
