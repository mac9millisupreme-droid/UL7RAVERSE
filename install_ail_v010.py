from pathlib import Path
import textwrap

ROOT = Path.cwd()
PKG = ROOT / "ul7ra_continue"
PKG.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------------
# AIL v0.1
# ---------------------------------------------------------------------
(PKG / "ail.py").write_text(textwrap.dedent(r'''
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
''').lstrip())

# ---------------------------------------------------------------------
# Governance state machine
# ---------------------------------------------------------------------
(PKG / "governance.py").write_text(textwrap.dedent(r'''
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
''').lstrip())

# ---------------------------------------------------------------------
# AIL regression tests
# ---------------------------------------------------------------------
(ROOT / "test_ul7ra_continue_ail.py").write_text(textwrap.dedent(r'''
    from ul7ra_continue import ail, governance


    def verification(
        historical_checkpoint_present=False,
    ):
        return {
            "root": "/data/data/com.termux/files/home/UL7RAVERSE",
            "head": "63c1d6080cc91f100f2f1c37ee22706ae96c93d4",
            "checkpoint": {
                "historical_checkpoint_present":
                    historical_checkpoint_present
            },
        }


    def purple_pass():
        return {
            "purple_state": "PASS",
            "promotion_authorized": False,
            "execution_authorized": False,
            "workaround_permitted": True,
        }


    def purple_veto():
        return {
            "purple_state": "VETO",
            "promotion_authorized": False,
            "execution_authorized": False,
            "workaround_permitted": False,
        }


    def test_ail_missing_historical_checkpoint_requires_review():
        result = ail.evaluate(
            verification(False),
            purple_pass(),
        )

        assert result["ail_state"] == "NEEDS_REVIEW"
        assert result["promotion_authorized"] is False
        assert result["execution_authorized"] is False
        assert result["workaround_permitted"] is False


    def test_ail_pass_requires_historical_checkpoint():
        result = ail.evaluate(
            verification(True),
            purple_pass(),
        )

        assert result["ail_state"] == "PASS"
        assert result["promotion_authorized"] is False
        assert result["execution_authorized"] is False
        assert result["workaround_permitted"] is False


    def test_ail_cannot_override_purple_veto():
        result = ail.evaluate(
            verification(True),
            purple_veto(),
        )

        assert result["ail_state"] == "BLOCKED"
        assert result["promotion_authorized"] is False
        assert result["execution_authorized"] is False


    def test_deterministic_purple_to_ail_review_transition(monkeypatch):
        monkeypatch.setattr(
            governance.purple,
            "analyze",
            lambda verification_result: purple_pass(),
        )

        result = governance.govern(verification(False))

        assert result["purple"]["purple_state"] == "PASS"
        assert result["ail"]["ail_state"] == "NEEDS_REVIEW"
        assert result["next"] == "AIL_REVIEW"
        assert result["status"] == "CANNOT_SAFELY_CONTINUE"
        assert result["promotion"] == "REFUSED"
        assert result["execution_authorized"] is False
        assert result["workaround_permitted"] is False


    def test_ail_pass_transitions_to_trinity_without_promotion(monkeypatch):
        monkeypatch.setattr(
            governance.purple,
            "analyze",
            lambda verification_result: purple_pass(),
        )

        result = governance.govern(verification(True))

        assert result["purple"]["purple_state"] == "PASS"
        assert result["ail"]["ail_state"] == "PASS"
        assert result["next"] == "TRINITY"
        assert result["status"] == "VERIFIED_FOR_REVIEW"
        assert result["promotion"] == "REFUSED"
        assert result["execution_authorized"] is False


    def test_unknown_ail_state_fails_closed(monkeypatch):
        monkeypatch.setattr(
            governance.purple,
            "analyze",
            lambda verification_result: purple_pass(),
        )
        monkeypatch.setattr(
            governance.ail,
            "evaluate",
            lambda verification_result, purple_result: {
                "ail_state": "NOT_A_REAL_STATE"
            },
        )

        result = governance.govern(verification(False))

        assert result["ail_state"] == "UNKNOWN"
        assert result["next"] == "AIL_REVIEW"
        assert result["promotion"] == "REFUSED"
        assert result["execution_authorized"] is False
''').lstrip())

# ---------------------------------------------------------------------
# Version marker
# ---------------------------------------------------------------------
(PKG / "__init__.py").write_text(
    '__version__ = "0.1.2"\n'
)

print("=== UL7RA AIL v0.1 PATCH INSTALLED ===")
print(f"Package: {PKG}")
print("State machine: VERIFICATION -> PURPLE -> AIL -> TRINITY")
print("Historical checkpoint missing => AIL NEEDS_REVIEW")
print("Promotion authority: REFUSED")
print("Execution authority: DISABLED")
