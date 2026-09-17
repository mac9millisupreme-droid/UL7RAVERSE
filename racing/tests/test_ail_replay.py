import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from ail.evidence import evidence_hash
from ail.replay import verify_replay

def test_replay_valid():
    data = {"a": 1, "b": [2,3]}
    h = evidence_hash(data)
    assert verify_replay(h, data)

def test_replay_invalid():
    data = {"a": 1, "b": [2,3]}
    h = evidence_hash(data)
    assert not verify_replay(h, {"a": 2})
