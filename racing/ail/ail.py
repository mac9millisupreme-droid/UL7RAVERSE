from typing import Dict, Any, List
from .provenance import validate_provenance
from .temporal import check_temporal_integrity
from .adversarial import run_adversarial_checks
from .uncertainty import estimate_uncertainty
from .shadow import compare_shadow_predictions
from .calibration import is_calibrated
from .distribution import check_distribution_eligibility
from .evidence import evidence_hash
from .replay import verify_replay
from .decision import DecisionState
from .schemas import PredictionInput

class AILGate:
    """Central gate that evaluates integrity and produces a decision state."""
    def __init__(self, pred_input: PredictionInput,
                 feature_timestamps: List[Dict[str, str]],
                 race_start_timestamp: str,
                 uncertainty_params: Dict[str, Any],
                 primary_pred: Dict[str, float],
                 shadow_preds: Dict[str, Dict[str, float]] = None,
                 calibration_available: bool = False,
                 distribution_shift_detected: bool = False,
                 evidence_replay_hash: str = None):
        self.pred_input = pred_input
        self.feature_timestamps = feature_timestamps
        self.race_start_timestamp = race_start_timestamp
        self.uncertainty_params = uncertainty_params
        self.primary_pred = primary_pred
        self.shadow_preds = shadow_preds or {}
        self.calibration_available = calibration_available
        self.distribution_shift_detected = distribution_shift_detected
        self.evidence_replay_hash = evidence_replay_hash

    def evaluate(self) -> Dict[str, Any]:
        # Provenance
        prov_result = validate_provenance(self.pred_input)
        provenance_valid = prov_result["status"] == "PASS"

        # Temporal
        temporal_result = check_temporal_integrity(
            self.pred_input.decision_timestamp,
            self.feature_timestamps,
            self.race_start_timestamp
        )
        temporal_valid = temporal_result["status"] == "PASS"

        # Feature availability
        feature_availability_valid = all(f.get("timestamp") for f in self.feature_timestamps)

        # Adversarial
        adversarial_violations = run_adversarial_checks(
            self.pred_input,
            self.feature_timestamps,
            self.race_start_timestamp
        )
        adversarial_valid = len(adversarial_violations) == 0

        # Uncertainty
        uncertainty = estimate_uncertainty(**self.uncertainty_params)
        uncertainty_known = uncertainty["status"] == "KNOWN"

        # Shadow verification
        if self.shadow_preds:
            shadow_result = compare_shadow_predictions(self.primary_pred, self.shadow_preds)
            independent_verification_valid = shadow_result["status"] == "PASS"
        else:
            independent_verification_valid = False

        # Calibration
        calibrated = is_calibrated(self.calibration_available)

        # Distribution
        distribution_result = check_distribution_eligibility(
            {}, shift_detected=self.distribution_shift_detected
        )
        distribution_eligible = distribution_result["eligible"]

        # Evidence replay: only if a hash is provided
        if self.evidence_replay_hash:
            reconstructed = {
                "pred_input": self.pred_input.__dict__,
                "primary_pred": self.primary_pred
            }
            evidence_replay_valid = verify_replay(self.evidence_replay_hash, reconstructed)
        else:
            evidence_replay_valid = True   # not applicable, do not block

        # Decision state ordering
        if (not provenance_valid) or (not temporal_valid) or (not adversarial_valid):
            decision_state = "BLOCKED"
        elif self.evidence_replay_hash is not None and not evidence_replay_valid:
            decision_state = "BLOCKED"
        elif not uncertainty_known:
            decision_state = "UNKNOWN"
        elif self.shadow_preds and not independent_verification_valid:
            decision_state = "NEEDS_REVIEW"
        elif self.primary_pred.get("edge") is None or self.primary_pred.get("ev") is None:
            decision_state = "INSUFFICIENT_DATA"
        elif not calibrated or not distribution_eligible:
            decision_state = "NO_BET"
        else:
            if (self.primary_pred.get("edge", 0) > 0 and
                self.primary_pred.get("ev", 0) > 0 and
                uncertainty["total"] <= 0.5):
                decision_state = "VALUE_CANDIDATE"
            else:
                decision_state = "WATCH"

        ail_verdict = decision_state

        ail_input = {
            "pred_input": self.pred_input.__dict__,
            "feature_timestamps": self.feature_timestamps,
            "race_start_timestamp": self.race_start_timestamp,
            "primary_pred": self.primary_pred,
            "shadow_preds": self.shadow_preds,
        }
        ail_evidence = {
            "provenance": prov_result,
            "temporal": temporal_result,
            "feature_availability_valid": feature_availability_valid,
            "adversarial": adversarial_violations,
            "uncertainty": uncertainty,
            "shadow": shadow_result if self.shadow_preds else {"status": "NOT_RUN"},
            "calibration": {"calibrated": calibrated},
            "distribution": distribution_result,
            "evidence_replay_valid": evidence_replay_valid,
        }
        ail_reasons = []
        if not provenance_valid:
            ail_reasons.append("Provenance invalid")
        if not temporal_valid:
            ail_reasons.append("Temporal integrity violated")
        if not feature_availability_valid:
            ail_reasons.append("Feature availability invalid")
        if not adversarial_valid:
            ail_reasons.append("Adversarial checks failed")
        if not uncertainty_known:
            ail_reasons.append("Uncertainty unknown")
        if not independent_verification_valid:
            ail_reasons.append("Shadow verification failed or not run")
        if not evidence_replay_valid:
            ail_reasons.append("Evidence replay failed")
        if not calibrated:
            ail_reasons.append("Model not calibrated")
        if not distribution_eligible:
            ail_reasons.append("Out of distribution")

        return {
            "AIL_INPUT": ail_input,
            "AIL_EVIDENCE": ail_evidence,
            "AIL_VERDICT": ail_verdict,
            "AIL_REASONS": ail_reasons,
            "AIL_HASH": evidence_hash(ail_evidence),
        }
