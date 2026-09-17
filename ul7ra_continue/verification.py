import subprocess

def run_racing_gate(root):
    result = subprocess.run(
        ["python", "-m", "pytest", "racing/tests", "-q"],
        cwd=root,
        text=True,
        capture_output=True,
    )

    output = (result.stdout or "") + (result.stderr or "")

    return {
        "command": "python -m pytest racing/tests -q",
        "returncode": result.returncode,
        "status": "PASS" if result.returncode == 0 else "FAIL",
        "output": output[-4000:],
    }

def verify_state(state):
    result = {
        "promotion": "REFUSED",
        "historical_recovery": False,
        "next": "PURPLE_TEAM",
    }

    checkpoints = state["checkpoint"]["reconstructed"]

    if not checkpoints:
        result.update({
            "status": "INSUFFICIENT_DATA",
            "next": "RECONSTRUCTED_CHECKPOINT_DISCOVERY",
        })
        return result

    if not all(item["sha256_match"] for item in checkpoints):
        result.update({
            "status": "BLOCKED",
            "next": "CHECKPOINT_INTEGRITY_REVIEW",
        })
        return result

    gate = run_racing_gate(state["root"])
    result["racing_gate"] = gate

    if gate["status"] != "PASS":
        result.update({
            "status": "BLOCKED",
            "next": "RACING_GATE_FAILURE",
        })
        return result

    result["status"] = "VERIFIED_FOR_REVIEW"
    return result

def print_verification(result):
    import json
    print(json.dumps(result, indent=2, sort_keys=True))
