from typing import Optional

def market_probability(decimal_odds: Optional[float]) -> Optional[float]:
    if decimal_odds is None or decimal_odds <= 1.0:
        return None
    return 1.0 / decimal_odds

def calculate_edge(model_prob: float, market_prob: float) -> float:
    return model_prob - market_prob

def expected_value(model_prob: float, decimal_odds: Optional[float]) -> Optional[float]:
    if decimal_odds is None or decimal_odds <= 1.0:
        return None
    return model_prob * decimal_odds - 1.0
