from enum import Enum


class Decision(str, Enum):
    WATCH = "WATCH"
    VALUE_CANDIDATE = "VALUE_CANDIDATE"
    NO_BET = "NO_BET"
    BLOCKED = "BLOCKED"
    FAILED = "FAILED"


class AssuranceState(str, Enum):
    OBSERVED = "OBSERVED"
    VERIFIED = "VERIFIED"
    INFERRED = "INFERRED"
    PROPOSED = "PROPOSED"
    UNPROVEN = "UNPROVEN"
    UNKNOWN = "UNKNOWN"
    FAILED = "FAILED"
    BLOCKED = "BLOCKED"
