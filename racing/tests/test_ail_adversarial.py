import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from ail.schemas import PredictionInput
from ail.adversarial import run_adversarial_checks

def test_adversarial_detects_temporal_violation():
    pred = PredictionInput(race_id="r1", horse_id="h1", model_version="v1",
                           data_timestamp="2023-01-01T00:00:00",
                           decision_timestamp="2023-01-01T00:00:00",
                           input_provenance={"source": "test"})
    features = [{"name": "odds", "timestamp": "2023-01-01T00:01:00"}]
    race_start = "2023-01-01T00:30:00"
    violations = run_adversarial_checks(pred, features, race_start)
    assert any("Temporal violation" in v for v in violations)

def test_adversarial_invalid_odds():
    pred = PredictionInput(race_id="r1", horse_id="h1", model_version="v1",
                           data_timestamp="2023-01-01T00:00:00",
                           decision_timestamp="2023-01-01T00:00:00",
                           input_provenance={"source": "test"},
                           odds=1.0)
    features = [{"name": "odds", "timestamp": "2023-01-01T00:00:00"}]
    race_start = "2023-01-01T00:30:00"
    violations = run_adversarial_checks(pred, features, race_start)
    assert any("Invalid odds" in v for v in violations)
