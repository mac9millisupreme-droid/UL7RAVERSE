from typing import Dict, Any

def estimate_uncertainty(sample_size: int,
                         ensemble_variance: float = None,
                         calibration_error: float = None) -> Dict[str, Any]:
    data_unc = 1.0 / (sample_size ** 0.5) if sample_size > 0 else 1.0
    model_unc = ensemble_variance if ensemble_variance is not None else 0.0
    calib_unc = calibration_error if calibration_error is not None else 0.0
    total = min(1.0, data_unc + model_unc + calib_unc)
    return {
        "total": total,
        "data": data_unc,
        "model": model_unc,
        "calibration": calib_unc,
        "status": "KNOWN" if total < 1.0 else "UNKNOWN"
    }
