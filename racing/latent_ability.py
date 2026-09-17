"""
Latent Horse Ability Estimator

Bayesian shrinkage estimate with numerically stable variance handling.
"""
from dataclasses import dataclass
from typing import List, Optional, Dict, Any
import math

@dataclass
class AbilityEstimate:
    horse_id: str
    mean: float
    variance: float
    sample_size: int
    shrinkage_factor: float  # weight toward prior (1 = fully prior)
    status: str  # "ESTIMATED", "INSUFFICIENT_DATA"

def estimate_ability(horse_id: str,
                     observed_scores: List[float],
                     population_mean: float = 0.0,
                     population_variance: float = 1.0,
                     min_sample: int = 5) -> AbilityEstimate:
    """Bayesian shrinkage with fixed variance floor."""
    # Input validation
    if not isinstance(horse_id, str) or not horse_id:
        raise ValueError("horse_id must be a non-empty string")
    if population_variance <= 0:
        raise ValueError("population_variance must be positive")
    if min_sample <= 0:
        raise ValueError("min_sample must be positive")
    if not isinstance(observed_scores, list):
        raise ValueError("observed_scores must be a list")

    # Clean and validate observations
    cleaned = []
    for i, score in enumerate(observed_scores):
        if not isinstance(score, (int, float)):
            raise ValueError(f"Observation {i} is not numeric")
        if math.isnan(score) or math.isinf(score):
            raise ValueError(f"Observation {i} is NaN or infinity")
        cleaned.append(float(score))

    n = len(cleaned)
    if n == 0:
        # Prior only
        return AbilityEstimate(
            horse_id=horse_id,
            mean=population_mean,
            variance=population_variance,
            sample_size=0,
            shrinkage_factor=1.0,  # fully prior
            status="INSUFFICIENT_DATA"
        )

    sample_mean = sum(cleaned) / n
    # Sample variance with Bessel correction (n-1), at least floor
    if n > 1:
        sample_var = sum((x - sample_mean) ** 2 for x in cleaned) / (n - 1)
    else:
        sample_var = population_variance  # for n=1, use prior variance as fallback

    # Add a small floor to avoid zero variance
    variance_floor = 1e-9
    sample_var = max(sample_var, variance_floor)
    population_variance = max(population_variance, variance_floor)

    # Shrinkage factor: k = population_variance / sample_var
    k = population_variance / sample_var
    weight_sample = n / (n + k)
    weight_prior = 1 - weight_sample

    posterior_mean = weight_sample * sample_mean + weight_prior * population_mean
    # Posterior variance: 1 / (n/sample_var + 1/population_variance)
    posterior_variance = 1.0 / (n / sample_var + 1.0 / population_variance)

    # Ensure finite and non-negative
    if not math.isfinite(posterior_mean) or not math.isfinite(posterior_variance) or posterior_variance < 0:
        raise ValueError("Numerical instability in ability estimate")

    return AbilityEstimate(
        horse_id=horse_id,
        mean=posterior_mean,
        variance=posterior_variance,
        sample_size=n,
        shrinkage_factor=weight_prior,
        status="ESTIMATED"
    )
