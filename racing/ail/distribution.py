def check_distribution_eligibility(features: Dict[str, Any] = None,
                                   shift_detected: bool = False) -> Dict[str, Any]:
    if shift_detected:
        return {"status": "OUT_OF_DISTRIBUTION", "eligible": False}
    return {"status": "IN_DISTRIBUTION", "eligible": True}
