"""
Market Intelligence - handles odds, probabilities, and market normalization.
"""
from dataclasses import dataclass
from typing import Dict, List, Optional, Any
import math

@dataclass
class MarketState:
    race_id: str
    market_probabilities: Dict[str, float]
    raw_implied_probabilities: Dict[str, float]
    overround: float
    normalized: bool

def market_probability_from_odds(decimal_odds: Optional[float]) -> Optional[float]:
    """Convert decimal odds to implied probability."""
    if decimal_odds is None or decimal_odds <= 1.0:
        return None
    return 1.0 / decimal_odds

def normalize_market(implied_probs: Dict[str, float]) -> Dict[str, float]:
    """Normalize implied probabilities to sum to 1 (remove overround)."""
    total = sum(implied_probs.values())
    if total <= 0:
        return {}
    return {k: v / total for k, v in implied_probs.items()}

def compute_edge(model_prob: float, market_prob: float) -> float:
    """Edge = model probability - market probability."""
    return model_prob - market_prob

def compute_ev(model_prob: float, decimal_odds: float) -> Optional[float]:
    """Expected value for decimal odds."""
    if decimal_odds is None or decimal_odds <= 1.0:
        return None
    return model_prob * (decimal_odds - 1) - (1 - model_prob)
