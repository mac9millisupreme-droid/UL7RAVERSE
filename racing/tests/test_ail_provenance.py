import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from ail.schemas import PredictionInput
from ail.provenance import validate_provenance

def test_provenance_missing_fields():
    pred = PredictionInput(race_id="r1", horse_id=None, model_version="v1",
                           data_timestamp="2023-01-01T00:00:00",
                           decision_timestamp="2023-01-01T00:00:00",
                           input_provenance={"source": "test"})
    res = validate_provenance(pred)
    assert res["status"] == "FAIL"

def test_provenance_pass():
    pred = PredictionInput(race_id="r1", horse_id="h1", model_version="v1",
                           data_timestamp="2023-01-01T00:00:00",
                           decision_timestamp="2023-01-01T00:00:00",
                           input_provenance={"source": "test"})
    res = validate_provenance(pred)
    assert res["status"] == "PASS"
