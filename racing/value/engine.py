from typing import Optional


def expected_value(
    probability: Optional[float],
    decimal_odds: Optional[float],
) -> Optional[float]:
    if probability is None or decimal_odds is None:
        return None
    if decimal_odds <= 1.0:
        return None
    return probability * decimal_odds - 1.0
