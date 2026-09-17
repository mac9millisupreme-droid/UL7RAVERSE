import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from verification_artifact import make_artifact, write_artifact, GATES


def test_schema_contract():
    artifact = make_artifact("TEST_DETERMINISTIC_RUN")
    required = {
        "artifact_version",
        "run_id",
        "created_at",
        "repository",
        "git",
        "baseline",
        "environment",
        "gates",
        "decision",
        "promotion",
        "integrity",
    }
    assert required <= set(artifact)
    assert set(artifact["gates"]) == set(GATES)


def test_initial_state_cannot_promote():
    artifact = make_artifact("TEST_NO_PROMOTE")
    assert artifact["promotion"]["status"] == "NO_PROMOTE"
    assert artifact["decision"]["status"] == "NO_DECISION"


def test_canonical_integrity():
    import hashlib
    import json

    artifact = make_artifact("TEST_HASH")
    supplied = artifact["integrity"]["canonical_json_sha256"]

    unsigned = dict(artifact)
    unsigned.pop("integrity")

    canonical = json.dumps(
        unsigned,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode()

    assert hashlib.sha256(canonical).hexdigest() == supplied


def test_write():
    artifact = make_artifact("TEST_WRITE")
    path = write_artifact(artifact)
    assert path.exists()
    loaded = json.loads(path.read_text())
    assert loaded["run_id"] == "TEST_WRITE"
    path.unlink()


def test_replay_same_semantic_input():
    a = make_artifact("REPLAY_TEST")
    b = make_artifact("REPLAY_TEST")

    # Timestamp is intentionally excluded from this structural comparison.
    a.pop("created_at")
    b.pop("created_at")

    assert a["run_id"] == b["run_id"]
    assert a["gates"] == b["gates"]
    assert a["decision"] == b["decision"]
    assert a["promotion"] == b["promotion"]
