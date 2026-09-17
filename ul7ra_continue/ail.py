import json

AIL_STATES = {
    "PASS",
    "WATCH",
    "NEEDS_REVIEW",
    "BLOCKED",
    "INSUFFICIENT_DATA",
    "UNKNOWN",
}


def _get(result, *paths, default=None):
    """Read the first existing value from nested dictionaries."""
    for path in paths:
        cur = result
        try:
            for key in path:
                if not isinstance(cur, dict) or key not in cur:
                    raise KeyError
                cur = cur[key]
            return cur
        except KeyError:
            continue
    return default


def evaluate(verification_result, purple_result):
    """
    UL7RA AIL v0.1

    AIL evaluates governance fitness only.

    AIL NEVER:
      - promotes
      - authorizes execution
      - overrides Purple
      - authorizes workarounds
      - rewrites history
      - converts missing evidence into PASS
    """

    if not isinstance(verification_result, dict):
        return {
            "ail_state": "INSUFFICIENT_DATA",
            "reason": "Verification result is missing or invalid.",
            "promotion_authorized": False,
            "execution_authorized": False,
            "workaround_permitted": False,
        }

    if not isinstance(purple_result, dict):
        return {
            "ail_state": "INSUFFICIENT_DATA",
            "reason": "Purple result is missing or invalid.",
            "promotion_authorized": False,
            "execution_authorized": False,
            "workaround_permitted": False,
        }

    purple_state = purple_result.get("purple_state")

    # Constitutional boundary: AIL cannot override Purple VETO.
    if purple_state == "VETO":
        return {
            "ail_state": "BLOCKED",
            "reason": "Purple VETO cannot be overridden by AIL.",
            "promotion_authorized": False,
            "execution_authorized": False,
            "workaround_permitted": False,
        }

    # Purple must actually pass before AIL can classify governance fitness.
    if purple_state != "PASS":
        return {
            "ail_state": "NEEDS_REVIEW",
            "reason": (
                f"Purple state is {purple_state!r}; "
                "AIL requires governance review before continuation."
            ),
            "promotion_authorized": False,
            "execution_authorized": False,
            "workaround_permitted": False,
        }

    root = verification_result.get("root")
    head = verification_result.get("head")

    if not root:
        return {
            "ail_state": "INSUFFICIENT_DATA",
            "reason": "Missing repository root.",
            "promotion_authorized": False,
            "execution_authorized": False,
            "workaround_permitted": False,
        }

    if not head:
        return {
            "ail_state": "INSUFFICIENT_DATA",
            "reason": "Missing Git HEAD.",
            "promotion_authorized": False,
            "execution_authorized": False,
            "workaround_permitted": False,
        }

    # The actual v0.1.1 discovery structure stores this under
    # checkpoint.historical_checkpoint_present.
    historical_present = _get(
        verification_result,
        ("historical_checkpoint_present",),
        ("checkpoint", "historical_checkpoint_present"),
        default=None,
    )

    # Missing historical evidence is NOT converted into PASS.
    # The reconstructed checkpoint is explicitly not historical recovery.
    if historical_present is False:
        return {
            "ail_state": "NEEDS_REVIEW",
            "reason": "Historical checkpoint not recovered; reconstructed baseline exists but does not replace historical evidence.",
            "promotion_authorized": False,
            "execution_authorized": False,
            "workaround_permitted": False,
        }

    if historical_present is None:
        return {
            "ail_state": "INSUFFICIENT_DATA",
            "reason": "Historical checkpoint status is unavailable.",
            "promotion_authorized": False,
            "execution_authorized": False,
            "workaround_permitted": False,
        }

    # AIL v0.1 never authorizes promotion or execution.
    return {
        "ail_state": "PASS",
        "reason": "Governance fitness sufficient for Trinity review. Promotion remains refused.",
        "promotion_authorized": False,
        "execution_authorized": False,
        "workaround_permitted": False,
    }


def print_ail(result):
    print(json.dumps(result, indent=2, sort_keys=True))
