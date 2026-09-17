"""
Decision Composer - combines all evidence into candidate assessment.
Does NOT bypass AIL. AIL remains final authority.
"""
from dataclasses import dataclass
from typing import Dict, List, Optional, Any
from enum import Enum

class DecisionCandidate(Enum):
    WATCH = "WATCH"
    VALUE_CANDIDATE = "VALUE_CANDIDATE"
    NO_BET = "NO_BET"
    BLOCKED = "BLOCKED"
    INSUFFICIENT_DATA = "INSUFFICIENT_DATA"
    NEEDS_REVIEW = "NEEDS_REVIEW"
    UNKNOWN = "UNKNOWN"

@dataclass
class CandidateAssessment:
    race_id: str
    horse_id: str
    model_probability: float
    market_probability: Optional[float]
    edge: Optional[float]
    ev: Optional[float]
    uncertainty: float
    calibration_status: str
    fragility: str
    data_sufficiency: str
    distribution_shift: str
    model_disagreement: bool
    decision: DecisionCandidate

def compose_candidate(probability: float,
                      market_prob: Optional[float],
                      edge: Optional[float],
                      ev: Optional[float],
                      uncertainty: float,
                      calibrated: bool,
                      distribution_eligible: bool,
                      model_agreement: bool) -> DecisionCandidate:
    """Compose decision based on evidence quality."""
    if not distribution_eligible:
        return DecisionCandidate.NO_BET
    if not calibrated:
        return DecisionCandidate.NO_BET
    if ev is None or edge is None:
        return DecisionCandidate.INSUFFICIENT_DATA
    if edge <= 0 or ev <= 0:
        return DecisionCandidate.NO_BET
    if uncertainty > 0.5:
        return DecisionCandidate.NEEDS_REVIEW
    if not model_agreement:
        return DecisionCandidate.NEEDS_REVIEW
    return DecisionCandidate.VALUE_CANDIDATE
