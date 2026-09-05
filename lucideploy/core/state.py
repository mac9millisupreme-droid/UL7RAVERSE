from enum import Enum

class State(str, Enum):
    DISCOVERED = "DISCOVERED"
    VERIFIED = "VERIFIED"
    READY = "READY"
    DEPLOYING = "DEPLOYING"
    CONNECTED = "CONNECTED"
    PUBLIC = "PUBLIC"
    PRODUCTION = "PRODUCTION"
    DEGRADED = "DEGRADED"
    BLOCKED = "BLOCKED"
    ROLLBACK_REQUIRED = "ROLLBACK_REQUIRED"

ALLOWED = {
    State.DISCOVERED: {State.VERIFIED, State.BLOCKED},
    State.VERIFIED: {State.READY, State.BLOCKED},
    State.READY: {State.DEPLOYING, State.BLOCKED},
    State.DEPLOYING: {State.CONNECTED, State.DEGRADED, State.ROLLBACK_REQUIRED},
    State.CONNECTED: {State.PUBLIC, State.DEGRADED, State.ROLLBACK_REQUIRED},
    State.PUBLIC: {State.PRODUCTION, State.DEGRADED, State.ROLLBACK_REQUIRED},
    State.PRODUCTION: {State.DEGRADED, State.ROLLBACK_REQUIRED},
    State.DEGRADED: {State.ROLLBACK_REQUIRED, State.BLOCKED},
    State.ROLLBACK_REQUIRED: {State.BLOCKED, State.DISCOVERED},
    State.BLOCKED: set()
}

def transition(current: str, target: str) -> str:
    try:
        c = State(current)
        t = State(target)
    except ValueError:
        raise RuntimeError("UNKNOWN_STATE")
    if t not in ALLOWED[c]:
        raise RuntimeError(f"INVALID_PROMOTION:{c.value}->{t.value}")
    return t.value
