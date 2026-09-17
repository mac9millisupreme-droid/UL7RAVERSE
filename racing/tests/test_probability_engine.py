import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import math
import pytest
from probability_engine import ProbabilityEstimate, compute_baseline_probability

def test_baseline_probability():
    p = compute_baseline_probability(4)
    assert p == pytest.approx(0.25)

def test_baseline_zero_entries():
    p = compute_baseline_probability(0)
    assert p == 0.0

def test_probability_estimate_validation():
    est = ProbabilityEstimate(
        race_id="r1", horse_id="h1", probability=0.5,
        model_version="v1", decision_timestamp="2023-01-01T00:00:00",
        input_evidence_hash="hash", uncertainty=0.1, status="MODEL_ESTIMATE"
    )
    est.validate()  # should not raise

def test_probability_out_of_bounds():
    est = ProbabilityEstimate(
        race_id="r1", horse_id="h1", probability=1.5,
        model_version="v1", decision_timestamp="2023-01-01T00:00:00",
        input_evidence_hash="hash", uncertainty=0.1, status="MODEL_ESTIMATE"
    )
    with pytest.raises(Exception):
        est.validate()
