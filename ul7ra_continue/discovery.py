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
