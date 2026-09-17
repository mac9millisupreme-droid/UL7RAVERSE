"""
Pace Model - estimates race shape and pace pressure.
Uses only evidence available at decision time.
"""
from dataclasses import dataclass
from typing import Dict, List, Optional, Any
import math

@dataclass
class PaceEstimate:
    race_id: str
    decision_timestamp: str
    expected_early_pace: float  # 0-1 scale
    pace_pressure: float
    front_runner_density: float
    stalking_advantage: float
    closing_opportunity: float
    status: str  # ESTIMATED, INSUFFICIENT_DATA

    def validate(self):
        for val in [self.expected_early_pace, self.pace_pressure,
                    self.front_runner_density, self.stalking_advantage,
                    self.closing_opportunity]:
            if not math.isfinite(val) or val < 0 or val > 1:
                raise ValueError(f"Invalid pace value: {val}")

def estimate_pace(race_state: Dict[str, Any],
                  entries: List[Dict[str, Any]]) -> PaceEstimate:
    """Estimate pace from available entry data."""
    if not entries:
        return PaceEstimate(
            race_id=race_state.get("race_id", "unknown"),
            decision_timestamp=race_state.get("decision_timestamp", ""),
            expected_early_pace=0.5,
            pace_pressure=0.5,
            front_runner_density=0.5,
            stalking_advantage=0.0,
            closing_opportunity=0.0,
            status="INSUFFICIENT_DATA"
        )
    
    # If we have pace ratings, use them
    pace_ratings = [e.get("pace_rating", 0.5) for e in entries if e.get("pace_rating")]
    if pace_ratings:
        avg_pace = sum(pace_ratings) / len(pace_ratings)
        pace_pressure = min(1.0, avg_pace * 1.2)
        return PaceEstimate(
            race_id=race_state.get("race_id", "unknown"),
            decision_timestamp=race_state.get("decision_timestamp", ""),
            expected_early_pace=avg_pace,
            pace_pressure=pace_pressure,
            front_runner_density=avg_pace,
            stalking_advantage=0.3,
            closing_opportunity=0.3,
            status="ESTIMATED"
        )
    
    return PaceEstimate(
        race_id=race_state.get("race_id", "unknown"),
        decision_timestamp=race_state.get("decision_timestamp", ""),
        expected_early_pace=0.5,
        pace_pressure=0.5,
        front_runner_density=0.5,
        stalking_advantage=0.0,
        closing_opportunity=0.0,
        status="INSUFFICIENT_DATA"
    )
