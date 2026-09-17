
import json
import subprocess

def test_import():
    import ul7ra_continue
    assert ul7ra_continue.__version__ == "0.1.0"

def test_state():
    result = subprocess.run(
        ["python", "-m", "ul7ra_continue", "state"],
        text=True,
        capture_output=True,
        check=True,
    )

    data = json.loads(result.stdout)

    assert data["root"].endswith("/UL7RAVERSE")
    assert data["branch"]
    assert data["head"]

def test_governance_refuses_promotion():
    result = subprocess.run(
        ["python", "-m", "ul7ra_continue", "continue"],
        text=True,
        capture_output=True,
        check=True,
    )

    assert "PROMOTION: REFUSED" in result.stdout
    assert "EXECUTION AUTHORIZED: False" in result.stdout
