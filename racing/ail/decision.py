from enum import Enum

class DecisionState(Enum):
    WATCH = "WATCH"
    VALUE_CANDIDATE = "VALUE_CANDIDATE"
    NO_BET = "NO_BET"
    BLOCKED = "BLOCKED"
    FAILED = "FAILED"
    INSUFFICIENT_DATA = "INSUFFICIENT_DATA"
    NEEDS_REVIEW = "NEEDS_REVIEW"
    UNKNOWN = "UNKNOWN"

def make_decision(prospective_truth: bool,
                  edge: float = None,
                  ev: float = None,
                  uncertainty_total: float = None,
                  calibrated: bool = False,
                  distribution_eligible: bool = False) -> DecisionState:
    if not prospective_truth:
        return DecisionState.BLOCKED
    if not distribution_eligible:
        return DecisionState.NO_BET
    if not calibrated:
        return DecisionState.NO_BET
    if ev is None or edge is None:
        return DecisionState.INSUFFICIENT_DATA
    if edge <= 0 or ev <= 0:
        return DecisionState.NO_BET
    if uncertainty_total is not None and uncertainty_total > 0.5:
        return DecisionState.NEEDS_REVIEW
    return DecisionState.VALUE_CANDIDATE
