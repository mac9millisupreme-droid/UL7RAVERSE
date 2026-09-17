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
        f"{digest}  EVIDENCE.json\n"
    )

    return {
        "path": str(path),
        "sha256": digest,
        "status": "RECORDED",
    }

def print_evidence(result):
    print(json.dumps(result, indent=2, sort_keys=True))
