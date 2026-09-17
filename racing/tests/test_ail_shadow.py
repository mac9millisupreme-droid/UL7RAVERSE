import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from ail.shadow import compare_shadow_predictions

def test_shadow_within_tolerance():
    primary = {"prob": 0.3, "ev": 0.1}
    shadows = {"model_a": {"prob": 0.32, "ev": 0.12}}
    res = compare_shadow_predictions(primary, shadows, tolerance=0.05)
    assert res["status"] == "PASS"

def test_shadow_exceeds_tolerance():
    primary = {"prob": 0.3, "ev": 0.1}
    shadows = {"model_b": {"prob": 0.4, "ev": 0.3}}
    res = compare_shadow_predictions(primary, shadows, tolerance=0.05)
    assert res["status"] == "NEEDS_REVIEW"
