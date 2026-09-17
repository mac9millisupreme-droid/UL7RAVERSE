from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class ProbabilityResult:
    model_probability: Optional[float]
    market_implied_probability: Optional[float]
    edge: Optional[float]
    uncertainty: Optional[float]
    data_completeness: float


def market_probability(decimal_odds: Optional[float]) -> Optional[float]:
    if decimal_odds is None:
        return None
    if decimal_odds <= 1.0:
        return None
    return 1.0 / decimal_odds


def calculate_edge(
    model_probability: Optional[float],
    market_probability_value: Optional[float],
) -> Optional[float]:
    if model_probability is None or market_probability_value is None:
        return None
    return model_probability - market_probability_value
