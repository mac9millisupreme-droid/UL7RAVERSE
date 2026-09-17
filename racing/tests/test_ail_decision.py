import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from ail.decision import make_decision, DecisionState

def test_value_candidate():
    d = make_decision(True, edge=0.1, ev=0.2, uncertainty_total=0.2,
                      calibrated=True, distribution_eligible=True)
    assert d == DecisionState.VALUE_CANDIDATE

def test_blocked_prospective_truth():
    d = make_decision(False, edge=0.1, ev=0.2, uncertainty_total=0.2,
                      calibrated=True, distribution_eligible=True)
    assert d == DecisionState.BLOCKED

def test_no_bet_uncalibrated():
    d = make_decision(True, edge=0.1, ev=0.2, uncertainty_total=0.2,
                      calibrated=False, distribution_eligible=True)
    assert d == DecisionState.NO_BET
