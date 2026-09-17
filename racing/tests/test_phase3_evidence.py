import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import pytest
import json
from phase3_evidence import Phase3EvidencePackage, Phase3ValidationError

def make_valid_package():
    return Phase3EvidencePackage(
        race_id="r1",
        decision_timestamp="2023-01-01T00:00:00",
        race_start_timestamp="2023-01-01T00:30:00",
        race_state={
            "race_id": "r1",
            "entries": [
                {"horse_id": "h1"},
                {"horse_id": "h2"}
            ]
        },
        ability_estimates=[
            {"horse_id": "h1", "mean": 1.0, "variance": 0.5, "sample_size": 5,
             "shrinkage_factor": 0.3, "status": "ESTIMATED",
             "provenance": {"source": "test"}, "observation_timestamp": "2023-01-01T00:00:00"},
        ],
        feature_observation_timestamps={"field_size": "2023-01-01T00:00:00"}
    )

def test_valid_package():
    pkg = make_valid_package()
    pkg.validate_temporal()  # should not raise

def test_future_feature_timestamp():
    pkg = make_valid_package()
    pkg.feature_observation_timestamps["future"] = "2023-01-01T00:01:00"
    with pytest.raises(Phase3ValidationError):
        pkg.validate_temporal()

def test_future_ability_observation():
    pkg = make_valid_package()
    pkg.ability_estimates[0]["observation_timestamp"] = "2023-01-01T00:01:00"
    with pytest.raises(Phase3ValidationError):
        pkg.validate_temporal()

def test_race_before_decision():
    pkg = make_valid_package()
    pkg.race_start_timestamp = "2022-12-31T23:59:00"
    with pytest.raises(Phase3ValidationError):
        pkg.validate_temporal()

def test_horse_coverage():
    pkg = make_valid_package()
    cov = pkg.horse_coverage()
    assert cov["entries_seen"] == 2
    assert cov["entries_with_ability"] == 1
    assert cov["entries_without_ability"] == 1

def test_deterministic_serialization():
    pkg1 = make_valid_package()
    pkg2 = make_valid_package()
    assert pkg1.to_json() == pkg2.to_json()
    assert pkg1.to_hash() == pkg2.to_hash()

def test_no_random_values():
    pkg1 = make_valid_package()
    pkg2 = make_valid_package()
    assert pkg1.to_dict() == pkg2.to_dict()
