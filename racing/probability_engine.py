"""
Probability Engine - consumes Phase3 evidence, produces calibrated probabilities.
"""
from dataclasses import dataclass
from typing import Dict, List, Optional, Any
import math

class ProbabilityError(Exception):
    pass

@dataclass
class ProbabilityEstimate:
    race_id: str
    horse_id: str
    probability: float
    model_version: str
    decision_timestamp: str
    input_evidence_hash: str
    uncertainty: float
    status: str  # PRIOR, MODEL_ESTIMATE, CALIBRATED_PROBABILITY

    def validate(self):
        if not math.isfinite(self.probability):
            raise ProbabilityError(f"Non-finite probability for {self.horse_id}")
        if self.probability < 0 or self.probability > 1:
            raise ProbabilityError(f"Probability out of bounds for {self.horse_id}: {self.probability}")
        if not math.isfinite(self.uncertainty) or self.uncertainty < 0:
            raise ProbabilityError(f"Invalid uncertainty for {self.horse_id}")

def compute_baseline_probability(n_entries: int) -> float:
    """Uniform prior."""
    if n_entries <= 0:
        return 0.0
    return 1.0 / n_entries

def compute_ability_weighted_probability(ability_estimates: List[Dict[str, Any]],
                                         n_entries: int) -> Dict[str, float]:
    """Softmax-like transformation of ability means to probabilities."""
    if n_entries <= 0:
        return {}
    
    # Extract means, handle missing ability
    means = []
    horse_ids = []
    for est in ability_estimates:
        if est.get("status") == "ESTIMATED":
            means.append(est["mean"])
            horse_ids.append(est["horse_id"])
    
    if not means:
        # Uniform if no ability estimates
        return {hid: 1.0/n_entries for hid in [e.get("horse_id") for e in [] ]}
    
    # Softmax with temperature
    max_mean = max(means)
    exp_means = [math.exp(m - max_mean) for m in means]
    total = sum(exp_means)
    
    probs = {}
    for hid, exp_m in zip(horse_ids, exp_means):
        probs[hid] = exp_m / total
    
    return probs
