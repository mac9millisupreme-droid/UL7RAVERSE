import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import pytest
from race_state_reconstruction import RaceStateSnapshot, TemporalViolation

def test_valid_snapshot():
    snap = RaceStateSnapshot(
        race_id="r1",
        decision_timestamp="2023-01-01T00:00:00",
        race_start_timestamp="2023-01-01T00:30:00",
        entries=[{"horse_id": "h1", "observation_timestamp": "2023-01-01T00:00:00"}]
    )
    snap.validate_temporal()

def test_future_entry_timestamp():
    snap = RaceStateSnapshot(
        race_id="r1",
        decision_timestamp="2023-01-01T00:00:00",
        race_start_timestamp="2023-01-01T00:30:00",
        entries=[{"horse_id": "h1", "observation_timestamp": "2023-01-01T00:01:00"}]
    )
    with pytest.raises(TemporalViolation):
        snap.validate_temporal()

def test_race_before_decision():
    snap = RaceStateSnapshot(
        race_id="r1",
        decision_timestamp="2023-01-01T00:00:00",
        race_start_timestamp="2022-12-31T23:59:00",
        entries=[]
    )
    with pytest.raises(TemporalViolation):
        snap.validate_temporal()

def test_equal_timestamp_allowed():
    snap = RaceStateSnapshot(
        race_id="r1",
        decision_timestamp="2023-01-01T00:00:00",
        race_start_timestamp="2023-01-01T00:30:00",
        entries=[{"horse_id": "h1", "observation_timestamp": "2023-01-01T00:00:00", "odds": 3.0}]
    )
    snap.validate_temporal()  # should pass

def test_missing_observation_timestamp_with_evidence():
    snap = RaceStateSnapshot(
        race_id="r1",
        decision_timestamp="2023-01-01T00:00:00",
        race_start_timestamp="2023-01-01T00:30:00",
        entries=[{"horse_id": "h1", "odds": 3.0}]  # missing timestamp
    )
    with pytest.raises(TemporalViolation):
        snap.validate_temporal()
