from __future__ import annotations

import hashlib
import json
import platform
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "verification_artifacts" / "runs"

GATES = (
    "BUILD",
    "TEST",
    "ADVERSARIAL",
    "PROVENANCE",
    "TEMPORAL",
    "AIL",
    "LUCITEST",
    "TRINITY",
)

BASELINE_ID = "FORENSIC_PHASE0_20260909T100256Z"


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def git(*args: str) -> str:
    try:
        return subprocess.check_output(
            ["git", *args],
            cwd=ROOT,
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except Exception:
        return "UNKNOWN"


def canonical_bytes(obj: dict) -> bytes:
    return json.dumps(
        obj,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")


def make_artifact(run_id: str | None = None) -> dict:
    rid = run_id or datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

    gates = {name: "UNKNOWN" for name in GATES}

    artifact = {
        "artifact_version": "1.0.0",
        "run_id": rid,
        "created_at": utc_now(),
        "repository": {
            "root": str(ROOT),
        },
        "git": {
            "head": git("rev-parse", "HEAD"),
            "branch": git("branch", "--show-current"),
            "worktree": "CLEAN" if not git("status", "--porcelain") else "DIRTY",
        },
        "baseline": {
            "id": BASELINE_ID,
            "status": "REFERENCE_ONLY",
        },
        "environment": {
            "platform": platform.platform(),
            "python": platform.python_version(),
        },
        "gates": gates,
        "decision": {
            "status": "NO_DECISION",
            "reason": "Artifact initialized; required verification gates have not executed.",
        },
        "promotion": {
            "status": "NO_PROMOTE",
            "authority": "PHONE_SIDE_UL7RAVERSE_GOVERNANCE",
        },
    }

    digest = hashlib.sha256(canonical_bytes(artifact)).hexdigest()

    artifact["integrity"] = {
        "canonical_json_sha256": digest,
    }

    return artifact


def write_artifact(artifact: dict) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f'{artifact["run_id"]}.json'
    path.write_bytes(canonical_bytes(artifact) + b"\n")
    return path


if __name__ == "__main__":
    artifact = make_artifact()
    path = write_artifact(artifact)

    print("UL7RAVERSE VERIFICATION ARTIFACT")
    print(f"RUN_ID: {artifact['run_id']}")
    print(f"PATH: {path}")
    print(f"PROMOTION: {artifact['promotion']['status']}")
    print(f"SHA256: {artifact['integrity']['canonical_json_sha256']}")
