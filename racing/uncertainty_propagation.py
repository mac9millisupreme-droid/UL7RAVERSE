"""
Uncertainty propagation - combines multiple uncertainty sources.
"""
from dataclasses import dataclass
from typing import Dict, List, Optional, Any
import math

@dataclass
class UncertaintyEstimate:
    total: float
    data_uncertainty: float
    model_uncertainty: float
    parameter_uncertainty: float
    distributional_uncertainty: float
    market_uncertainty: float
    temporal_uncertainty: float
    status: str  # KNOWN, UNKNOWN

def combine_uncertainties(components: Dict[str, float]) -> UncertaintyEstimate:
    """Combine uncertainty components (simple sum, bounded to 1)."""
    data = components.get("data", 0.0)
    model = components.get("model", 0.0)
    parameter = components.get("parameter", 0.0)
    distributional = components.get("distributional", 0.0)
    market = components.get("market", 0.0)
    temporal = components.get("temporal", 0.0)
    
    total = min(1.0, data + model + parameter + distributional + market + temporal)
    
    return UncertaintyEstimate(
        total=total,
        data_uncertainty=data,
        model_uncertainty=model,
        parameter_uncertainty=parameter,
        distributional_uncertainty=distributional,
        market_uncertainty=market,
        temporal_uncertainty=temporal,
        status="KNOWN" if total < 1.0 else "UNKNOWN"
    )
