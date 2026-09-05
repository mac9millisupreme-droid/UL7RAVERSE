from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lucideploy.core.state import State, transition

def test_valid_transition():
    assert transition("DISCOVERED", "VERIFIED") == "VERIFIED"

def test_unknown_state_fails():
    try:
        transition("BOGUS", "READY")
        assert False
    except RuntimeError as e:
        assert str(e) == "UNKNOWN_STATE"

def test_invalid_promotion_fails():
    try:
        transition("DISCOVERED", "PRODUCTION")
        assert False
    except RuntimeError as e:
        assert "INVALID_PROMOTION" in str(e)

def test_terminal_block():
    try:
        transition("BLOCKED", "READY")
        assert False
    except RuntimeError:
        pass
