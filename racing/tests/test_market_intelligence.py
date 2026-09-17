import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import pytest
from market_intelligence import market_probability_from_odds, normalize_market, compute_edge, compute_ev

def test_market_probability():
    assert market_probability_from_odds(2.0) == pytest.approx(0.5)

def test_invalid_odds():
    assert market_probability_from_odds(1.0) is None
    assert market_probability_from_odds(None) is None

def test_normalize_market():
    probs = {"a": 0.5, "b": 0.5, "c": 0.5}  # sum 1.5
    normalized = normalize_market(probs)
    assert sum(normalized.values()) == pytest.approx(1.0)

def test_edge():
    assert compute_edge(0.6, 0.5) == pytest.approx(0.1)

def test_ev():
    ev = compute_ev(0.6, 2.0)
    assert ev == pytest.approx(0.2)

def test_ev_invalid_odds():
    assert compute_ev(0.6, 1.0) is None
