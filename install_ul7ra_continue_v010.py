from pathlib import Path

ROOT = Path.home() / "UL7RAVERSE"
PKG = ROOT / "ul7ra_continue"
BIN = Path.home() / ".local" / "bin" / "ul7ra-continue"
TEST = ROOT / "test_ul7ra_continue.py"

files = {
    "__init__.py": '''
__version__ = "0.1.0"
''',

    "__main__.py": '''
from .cli import main

if __name__ == "__main__":
    raise SystemExit(main())
''',

    "discovery.py": '''
import subprocess
from pathlib import Path

ROOT = Path.home() / "UL7RAVERSE"

def run(cmd):
    return subprocess.run(
        cmd,
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=True,
    ).stdout.strip()

def sha256_file(path):
    import hashlib
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def discover_checkpoint():
    runs = ROOT / "verification_artifacts" / "runs"
    expected = (
        "491a2a5447ba2444394248372ecbee52fd848160f2f283861a90ffd60667c6eb"
    )

    found = []

    if runs.exists():
        for directory in runs.glob("reconstruct_server_racing_*"):
            checkpoint = directory / "CHECKPOINT.json"

            if checkpoint.is_file():
                actual = sha256_file(checkpoint)

                found.append({
                    "path": str(checkpoint),
                    "sha256": actual,
                    "expected_sha256": expected,
                    "sha256_match": actual == expected,
                    "historical_recovery": False,
                })

    return {
        "historical_checkpoint_present": False,
        "historical_recovery": False,
        "reconstructed": found,
    }

def discover_state():
    return {
        "root": str(ROOT),
        "branch": run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"]
        ),
        "head": run(
            ["git", "rev-parse", "HEAD"]
        ),
        "worktree": run(
            ["git", "status", "--porcelain"]
        ),
        "checkpoint": discover_checkpoint(),
    }

def print_state(state):
    import json
    print(json.dumps(state, indent=2, sort_keys=True))
''',

    "verification.py": '''
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
''',

    "evidence.py": '''
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

def write_evidence(state, verification):
    root = Path(state["root"])

    stamp = datetime.now(timezone.utc).strftime(
        "%Y%m%dT%H%M%SZ"
    )

    run_dir = (
        root
        / "verification_artifacts"
        / "continue_runs"
        / stamp
    )

    run_dir.mkdir(parents=True, exist_ok=False)

    payload = {
        "bridge_version": "0.1.0",
        "run_timestamp": stamp,
        "state": state,
        "verification": verification,
        "promotion": "REFUSED",
        "execution_authorized": False,
        "historical_recovery": False,
    }

    path = run_dir / "EVIDENCE.json"

    raw = json.dumps(
        payload,
        indent=2,
        sort_keys=True,
    ).encode()

    path.write_bytes(raw)

    digest = hashlib.sha256(raw).hexdigest()

    (run_dir / "EVIDENCE.sha256").write_text(
        f"{digest}  EVIDENCE.json\\n"
    )

    return {
        "path": str(path),
        "sha256": digest,
        "status": "RECORDED",
    }

def print_evidence(result):
    print(json.dumps(result, indent=2, sort_keys=True))
''',

    "governance.py": '''
def govern(verification):
    status = verification.get("status", "UNKNOWN")

    return {
        "status": status,
        "promotion": "REFUSED",
        "next": verification.get("next", "REVIEW"),
        "authority_boundary": "TRINITY",
        "execution_authorized": False,
        "message": (
            "UL7RA CONTINUE BRIDGE v0.1: "
            "promotion refused; unrestricted execution disabled."
        ),
    }

def print_governance(result):
    import json
    print(json.dumps(result, indent=2, sort_keys=True))
''',

    "cli.py": '''
import argparse

from . import discovery
from . import verification
from . import evidence
from . import governance

def main():
    parser = argparse.ArgumentParser(
        prog="ul7ra-continue"
    )

    parser.add_argument(
        "command",
        nargs="?",
        default="state",
        choices=[
            "state",
            "verify",
            "evidence",
            "continue",
        ],
    )

    args = parser.parse_args()

    state = discovery.discover_state()

    if args.command == "state":
        discovery.print_state(state)
        return 0

    verified = verification.verify_state(state)

    if args.command == "verify":
        verification.print_verification(verified)
        return 0

    recorded = evidence.write_evidence(
        state,
        verified,
    )

    if args.command == "evidence":
        evidence.print_evidence(recorded)
        return 0

    governed = governance.govern(verified)

    print("=== UL7RA CONTINUE BRIDGE v0.1 ===")
    print("STATE DISCOVERED")
    print(f"STATUS: {governed['status']}")
    print(f"NEXT: {governed['next']}")
    print(f"PROMOTION: {governed['promotion']}")
    print(
        "EXECUTION AUTHORIZED: "
        f"{governed['execution_authorized']}"
    )
    print(f"EVIDENCE: {recorded['path']}")
    print(governed["message"])

    return 0
''',
}

PKG.mkdir(parents=True, exist_ok=True)

for name, content in files.items():
    (PKG / name).write_text(content.lstrip())

BIN.parent.mkdir(parents=True, exist_ok=True)

BIN.write_text(
    "#!/data/data/com.termux/files/usr/bin/bash\n"
    'exec python -m ul7ra_continue "$@"\n'
)

BIN.chmod(0o755)

TEST.write_text(r'''
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
''')

print("INSTALL_COMPLETE")
print(f"PACKAGE={PKG}")
print(f"CLI={BIN}")
print(f"TEST={TEST}")
