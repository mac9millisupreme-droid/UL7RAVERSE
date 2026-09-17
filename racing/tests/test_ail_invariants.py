import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from ail.schemas import PredictionInput
from ail.ail import AILGate

def test_ail_blocks_on_temporal_violation():
    pred = PredictionInput(race_id="r1", horse_id="h1", model_version="v1",
                           data_timestamp="2023-01-01T00:00:00",
                           decision_timestamp="2023-01-01T00:00:00",
                           input_provenance={"source": "test"})
    gate = AILGate(
        pred_input=pred,
        feature_timestamps=[{"name": "odds", "timestamp": "2023-01-01T00:01:00"}],
        race_start_timestamp="2023-01-01T00:30:00",
        uncertainty_params={"sample_size": 100},
        primary_pred={"prob": 0.3, "edge": 0.1, "ev": 0.2},
        shadow_preds={"model_a": {"prob": 0.3, "edge": 0.1, "ev": 0.2}},
        calibration_available=True,
        distribution_shift_detected=False,
        evidence_replay_hash=None
    )
    result = gate.evaluate()
    assert result["AIL_VERDICT"] == "BLOCKED"

def test_ail_insufficient_data_missing_ev():
    pred = PredictionInput(race_id="r1", horse_id="h1", model_version="v1",
                           data_timestamp="2023-01-01T00:00:00",
                           decision_timestamp="2023-01-01T00:00:00",
                           input_provenance={"source": "test"})
    gate = AILGate(
        pred_input=pred,
        feature_timestamps=[{"name": "odds", "timestamp": "2023-01-01T00:00:00"}],
        race_start_timestamp="2023-01-01T00:30:00",
        uncertainty_params={"sample_size": 100},
        primary_pred={"prob": 0.3},  # missing ev
        shadow_preds={"model_a": {"prob": 0.3}},
        calibration_available=True,
        distribution_shift_detected=False,
        evidence_replay_hash=None
    )
    result = gate.evaluate()
    assert result["AIL_VERDICT"] == "INSUFFICIENT_DATA"
