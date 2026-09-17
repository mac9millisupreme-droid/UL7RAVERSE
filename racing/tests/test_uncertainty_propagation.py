import sys, os
import pytest
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from uncertainty_propagation import combine_uncertainties

def test_combine_uncertainties():
    u = combine_uncertainties({"data": 0.1, "model": 0.2})
    assert u.total == pytest.approx(0.3)
    assert u.status == "KNOWN"

def test_combine_uncertainties_unknown():
    u = combine_uncertainties({"data": 0.6, "model": 0.6})
    assert u.total == pytest.approx(1.0)
    assert u.status == "UNKNOWN"
