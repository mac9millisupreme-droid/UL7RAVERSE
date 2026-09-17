import json

from . import purple, ail


def govern(verification_result):
    """
    Deterministic UL7RA governance transition.

    VERIFICATION
         |
         v
    PURPLE
      | PASS
      v
    AIL
      | PASS
      v
    TRINITY

    Hard stops:
      PURPLE VETO
      AIL BLOCKED
      AIL NEEDS_REVIEW
      AIL INSUFFICIENT_DATA
      AIL UNKNOWN
    """

    purple_result = purple.analyze(verification_result)
    purple_state = purple_result.get("purple_state")

    # Purple VETO is terminal.
    if purple_state == "VETO":
        return {
            "status": "CANNOT_SAFELY_CONTINUE",
            "next": "PURPLE_VETO",
            "promotion": "REFUSED",
            "execution_authorized": False,
            "workaround_permitted": False,
            "purple": purple_result,
            "ail": {
                "ail_state": "BLOCKED",
                "reason": "Purple VETO cannot be overridden.",
                "promotion_authorized": False,
                "execution_authorized": False,
                "workaround_permitted": False,
            },
            "message": "Purple Team VETO: continuation blocked.",
        }

    # AIL evaluates only after Purple has passed.
    ail_result = ail.evaluate(
        verification_result,
        purple_result,
    )

    ail_state = ail_result.get("ail_state")

    # Governance hard stops.
    if ail_state in {
        "BLOCKED",
        "NEEDS_REVIEW",
        "INSUFFICIENT_DATA",
        "UNKNOWN",
    }:
        return {
            "status": "CANNOT_SAFELY_CONTINUE",
            "next": "AIL_REVIEW",
            "promotion": "REFUSED",
            "execution_authorized": False,
            "workaround_permitted": False,
            "purple": purple_result,
            "ail": ail_result,
            "message": (
                f"AIL {ail_state}: continuation blocked. "
                "Promotion refused. Execution unauthorized."
            ),
        }

    # WATCH is allowed to proceed, but remains explicitly flagged.
    if ail_state == "WATCH":
        return {
            "status": "VERIFIED_FOR_REVIEW",
            "next": "TRINITY",
            "promotion": "REFUSED",
            "execution_authorized": False,
            "workaround_permitted": False,
            "purple": purple_result,
            "ail": ail_result,
            "message": (
                "AIL WATCH: state may proceed to Trinity review. "
                "Promotion remains refused."
            ),
        }

    # Only AIL PASS transitions to Trinity.
    if ail_state == "PASS":
        return {
            "status": "VERIFIED_FOR_REVIEW",
            "next": "TRINITY",
            "promotion": "REFUSED",
            "execution_authorized": False,
            "workaround_permitted": False,
            "purple": purple_result,
            "ail": ail_result,
            "message": (
                "AIL PASS: state ready for Trinity governance review. "
                "Promotion remains refused."
            ),
        }

    # Fail closed for any unrecognized state.
    return {
        "status": "CANNOT_SAFELY_CONTINUE",
        "next": "AIL_REVIEW",
        "promotion": "REFUSED",
        "execution_authorized": False,
        "workaround_permitted": False,
        "purple": purple_result,
        "ail": {
            "ail_state": "UNKNOWN",
            "reason": f"Unrecognized AIL state: {ail_state!r}",
            "promotion_authorized": False,
            "execution_authorized": False,
            "workaround_permitted": False,
        },
        "message": "Unknown AIL state: fail closed.",
    }


def print_governance(result):
    print(json.dumps(result, indent=2, sort_keys=True))
