from typing import Dict, Any

def compare_shadow_predictions(primary: Dict[str, float],
                               shadows: Dict[str, Dict[str, float]],
                               tolerance: float = 0.05) -> Dict[str, Any]:
    deltas = {}
    within_tolerance = True
    for name, shadow_pred in shadows.items():
        for key in primary:
            if key in shadow_pred:
                delta = abs(primary[key] - shadow_pred[key])
                deltas[f"{name}_{key}"] = delta
                if delta > tolerance:
                    within_tolerance = False
    return {
        "deltas": deltas,
        "within_tolerance": within_tolerance,
        "status": "PASS" if within_tolerance else "NEEDS_REVIEW"
    }
