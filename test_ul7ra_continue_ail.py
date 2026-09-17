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

    assert result["ail"]["ail_state"] == "UNKNOWN"
    assert result["next"] == "AIL_REVIEW"
    assert result["promotion"] == "REFUSED"
    assert result["execution_authorized"] is False
