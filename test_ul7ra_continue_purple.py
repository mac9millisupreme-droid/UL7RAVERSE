from ul7ra_continue import purple


def test_purple_refuses_promotion():
    result = purple.analyze({
        "promotion": "REFUSED",
        "historical_recovery": False,
        "execution_authorized": False,
        "racing_gate": {
            "status": "PASS"
        },
    })

    assert result["purple_state"] == "PASS"
    assert result["promotion_authorized"] is False
    assert result["execution_authorized"] is False


def test_purple_veto_is_terminal():
    result = purple.analyze({
        "promotion": "PROMOTE",
        "historical_recovery": False,
        "execution_authorized": False,
        "racing_gate": {
            "status": "PASS"
        },
    })

    assert result["purple_state"] == "VETO"
    assert result["workaround_permitted"] is False
    assert result["promotion_authorized"] is False


def test_execution_authority_is_veto():
    result = purple.analyze({
        "promotion": "REFUSED",
        "historical_recovery": False,
        "execution_authorized": True,
        "racing_gate": {
            "status": "PASS"
        },
    })

    assert result["purple_state"] == "VETO"
