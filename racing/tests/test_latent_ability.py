import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import math
import pytest
from latent_ability import estimate_ability

def test_zero_observations():
    est = estimate_ability("h1", [], population_mean=0.0, population_variance=1.0)
    assert est.status == "INSUFFICIENT_DATA"
    assert est.mean == 0.0
    assert est.variance == 1.0
    assert est.sample_size == 0

def test_one_observation():
    est = estimate_ability("h1", [2.0], population_mean=0.0, population_variance=1.0)
    assert est.status == "ESTIMATED"
    assert math.isfinite(est.mean)
    assert math.isfinite(est.variance)
    assert est.variance >= 0
    assert est.sample_size == 1
    # Posterior mean should be between 0 and 2
    assert 0.0 < est.mean < 2.0

def test_constant_observations():
    est = estimate_ability("h1", [1.0, 1.0, 1.0], population_mean=0.0, population_variance=1.0)
    assert est.status == "ESTIMATED"
    assert math.isfinite(est.variance)
    assert est.variance > 0  # should not be zero
    assert est.sample_size == 3

def test_invalid_inputs():
    with pytest.raises(ValueError):
        estimate_ability("", [1.0])
    with pytest.raises(ValueError):
        estimate_ability("h1", [float('nan')])
    with pytest.raises(ValueError):
        estimate_ability("h1", [1.0], population_variance=0)
    with pytest.raises(ValueError):
        estimate_ability("h1", [1.0], min_sample=0)

def test_deterministic():
    est1 = estimate_ability("h1", [1.5, 2.0, 2.5], population_mean=0.0, population_variance=1.0)
    est2 = estimate_ability("h1", [1.5, 2.0, 2.5], population_mean=0.0, population_variance=1.0)
    assert est1 == est2
    assert est1.mean == est2.mean
    assert est1.variance == est2.variance
