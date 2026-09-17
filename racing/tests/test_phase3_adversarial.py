import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import pytest
from phase3_evidence import Phase3EvidencePackage, Phase3ValidationError

def make_package():
    return Phase3EvidencePackage(
        race_id="r1",
        decision_timestamp="2023-01-01T00:00:00",
        race_start_timestamp="2023-01-01T00:30:00",
        race_state={"entries": []},
        ability_estimates=[],
        feature_observation_timestamps={}
    )

def test_future_feature_rejected():
    pkg = make_package()
    pkg.feature_observation_timestamps["odds"] = "2023-01-01T00:01:00"
    with pytest.raises(Phase3ValidationError):
        pkg.validate_temporal()

def test_malformed_timestamp_rejected():
    pkg = make_package()
    pkg.feature_observation_timestamps["odds"] = "not-a-timestamp"
    with pytest.raises(Phase3ValidationError):
        pkg.validate_temporal()

def test_duplicate_horse_not_silently_merged():
    pkg = make_package()
    pkg.race_state["entries"] = [
        {"horse_id": "h1"}, {"horse_id": "h1"}
    ]
    # Our current logic just preserves duplicates; horse coverage counts them as two entries
    cov = pkg.horse_coverage()
    assert cov["entries_seen"] == 2  # duplicates preserved, not merged

def test_empty_race_ok():
    pkg = make_package()
    pkg.validate_temporal()
    cov = pkg.horse_coverage()
    assert cov["entries_seen"] == 0
