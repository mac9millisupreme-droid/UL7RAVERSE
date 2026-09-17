from racing.probability.engine import market_probability, calculate_edge
from racing.value.engine import expected_value
import pytest


def test_market_probability():
    assert market_probability(2.0) == 0.5


def test_edge():
    assert calculate_edge(0.60, 0.50) == pytest.approx(0.10)


def test_expected_value():
    assert expected_value(0.60, 2.0) == pytest.approx(0.20)


def test_missing_odds_produces_no_market_probability():
    assert market_probability(None) is None


def test_invalid_odds_produce_no_market_probability():
    assert market_probability(1.0) is None
    assert market_probability(0.5) is None


def test_missing_market_prevents_value():
    assert expected_value(0.60, None) is None
