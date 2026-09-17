import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import pytest
from race_state_reconstruction import RaceStateSnapshot, TemporalViolation
from latent_ability import estimate_ability

def test_future_timestamp_rejected():
    snap = RaceStateSnapshot(
        race_id="r1",
        decision_timestamp="2023-01-01T00:00:00",
        race_start_timestamp="2023-01-01T00:30:00",
        entries=[{"horse_id": "h1", "observation_timestamp": "2023-01-01T00:01:00"}]
    )
    with pytest.raises(TemporalViolation):
        snap.validate_temporal()

def test_nan_score_rejected():
    with pytest.raises(ValueError):
        estimate_ability("h1", [float('nan')])

def test_infinite_score_rejected():
    with pytest.raises(ValueError):
        estimate_ability("h1", [float('inf')])

def test_duplicate_horse_ids_not_silently_merged():
    # This is a structural check; our current snapshot just stores entries,
    # so we verify that duplicates are preserved (not merged) and validation still works.
    snap = RaceStateSnapshot(
        race_id="r1",
        decision_timestamp="2023-01-01T00:00:00",
        race_start_timestamp="2023-01-01T00:30:00",
        entries=[
            {"horse_id": "h1", "observation_timestamp": "2023-01-01T00:00:00"},
            {"horse_id": "h1", "observation_timestamp": "2023-01-01T00:00:00"}
        ]
    )
    # Should not raise for duplicates
    snap.validate_temporal()
    # But the entries list length remains 2
    assert len(snap.entries) == 2
