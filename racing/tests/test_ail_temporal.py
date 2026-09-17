import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from ail.temporal import check_temporal_integrity

def test_temporal_pass():
    res = check_temporal_integrity("2023-01-01T00:00:00",
                                   [{"name": "odds", "timestamp": "2023-01-01T00:00:00"}],
                                   "2023-01-01T00:30:00")
    assert res["status"] == "PASS"

def test_temporal_future_feature():
    res = check_temporal_integrity("2023-01-01T00:00:00",
                                   [{"name": "odds", "timestamp": "2023-01-01T00:01:00"}],
                                   "2023-01-01T00:30:00")
    assert res["status"] == "FAIL"

def test_temporal_race_before_decision():
    res = check_temporal_integrity("2023-01-01T00:00:00",
                                   [],
                                   "2022-12-31T23:59:00")
    assert res["status"] == "FAIL"
