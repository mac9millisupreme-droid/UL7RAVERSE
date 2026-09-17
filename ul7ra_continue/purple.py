import json

PURPLE_STATES = {"PASS", "WARN", "NEEDS_REVIEW", "VETO"}


def analyze(verification_result):
    findings = []
    hard_veto = False

    # ---------------------------------------------------------
    # 1. Historical recovery integrity
    # ---------------------------------------------------------
    if verification_result.get("historical_recovery") is True:
        findings.append(
            "VETO: historical recovery asserted without historical evidence."
        )
        hard_veto = True
    else:
        findings.append(
            "PASS: historical recovery is explicitly FALSE."
        )

    # ---------------------------------------------------------
    # 2. Promotion authority
    # ---------------------------------------------------------
    if verification_result.get("promotion") != "REFUSED":
        findings.append(
            "VETO: promotion was not explicitly refused."
        )
        hard_veto = True
    else:
        findings.append(
            "PASS: promotion explicitly refused."
        )

    # ---------------------------------------------------------
    # 3. Execution authority
    # ---------------------------------------------------------
    if verification_result.get("execution_authorized", False) is True:
        findings.append(
            "VETO: unrestricted execution authority detected."
        )
        hard_veto = True
    else:
        findings.append(
            "PASS: unrestricted execution authority is disabled."
        )

    # ---------------------------------------------------------
    # 4. Racing verification gate
    # ---------------------------------------------------------
    racing = verification_result.get("racing_gate")

    if racing is None:
        findings.append(
            "WARN: racing verification result not present."
        )
    elif racing.get("status") != "PASS":
        findings.append(
            "VETO: racing verification gate did not PASS."
        )
        hard_veto = True
    else:
        findings.append(
            "PASS: racing verification gate PASS."
        )

    # ---------------------------------------------------------
    # 5. Final classification
    # ---------------------------------------------------------
    if hard_veto:
        state = "VETO"
    elif any(item.startswith("WARN:") for item in findings):
        state = "WARN"
    else:
        state = "PASS"

    return {
        "purple_version": "0.1.1",
        "purple_state": state,
        "findings": findings,
        "workaround_permitted": state != "VETO",
        "promotion_authorized": False,
        "execution_authorized": False,
    }


def print_purple(result):
    print(json.dumps(result, indent=2, sort_keys=True))
