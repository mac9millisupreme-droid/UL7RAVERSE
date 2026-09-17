from enum import Enum

class TrinityState(Enum):
    BUILD = "BUILD"
    VERIFY = "VERIFY"
    LEARN = "LEARN"
    PROPOSED = "PROPOSED"
    VERIFIED = "VERIFIED"
    PROMOTION_PENDING = "PROMOTION_PENDING"
    BLOCKED = "BLOCKED"
    FAILED = "FAILED"

def map_ail_to_trinity(ail_verdict: str) -> TrinityState:
    if ail_verdict == "VALUE_CANDIDATE":
        return TrinityState.PROMOTION_PENDING
    elif ail_verdict in ("BLOCKED", "NO_BET", "NEEDS_REVIEW", "INSUFFICIENT_DATA", "UNKNOWN"):
        return TrinityState.BLOCKED
    else:
        return TrinityState.FAILED
