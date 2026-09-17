from dataclasses import dataclass, field
from typing import Any, Dict, Optional
from enum import Enum

class DataQuality(Enum):
    PRESENT = "PRESENT"
    MISSING = "MISSING"
    UNKNOWN = "UNKNOWN"
    INVALID = "INVALID"

@dataclass
class PredictionInput:
    race_id: str
    horse_id: str
    model_version: str
    data_timestamp: str
    decision_timestamp: str
    input_provenance: Dict[str, Any]
    odds: Optional[float] = None
    features: Dict[str, Any] = field(default_factory=dict)

    def validate_fields(self) -> Dict[str, DataQuality]:
        quality = {}
        for field_name in ["race_id", "horse_id", "model_version", "data_timestamp", "decision_timestamp"]:
            val = getattr(self, field_name, None)
            if val is None:
                quality[field_name] = DataQuality.MISSING
            elif val == "":
                quality[field_name] = DataQuality.INVALID
            else:
                quality[field_name] = DataQuality.PRESENT
        if not isinstance(self.input_provenance, dict) or not self.input_provenance:
            quality["input_provenance"] = DataQuality.MISSING
        else:
            quality["input_provenance"] = DataQuality.PRESENT
        return quality
