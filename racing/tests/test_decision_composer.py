import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from decision_composer import compose_candidate, DecisionCandidate

def test_value_candidate():
    d = compose_candidate(0.6, 0.5, 0.1, 0.2, 0.2, True, True, True)
    assert d == DecisionCandidate.VALUE_CANDIDATE

def test_no_bet_uncalibrated():
    d = compose_candidate(0.6, 0.5, 0.1, 0.2, 0.2, False, True, True)
    assert d == DecisionCandidate.NO_BET

def test_no_bet_out_of_distribution():
    d = compose_candidate(0.6, 0.5, 0.1, 0.2, 0.2, True, False, True)
    assert d == DecisionCandidate.NO_BET

def test_needs_review_model_disagreement():
    d = compose_candidate(0.6, 0.5, 0.1, 0.2, 0.2, True, True, False)
    assert d == DecisionCandidate.NEEDS_REVIEW

def test_insufficient_data():
    d = compose_candidate(0.6, None, None, None, 0.2, True, True, True)
    assert d == DecisionCandidate.INSUFFICIENT_DATA
