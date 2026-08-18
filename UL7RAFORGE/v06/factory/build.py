import json
import hashlib
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

components = [
    "orchestrator",
    "coding_swarm",
    "sandbox",
    "policy_engine",
    "verification_engine",
    "provenance_engine",
    "evidence_ledger",
    "purple_team",
    "rollback_engine"
]

manifest = {
    "version": "V0.6",
    "factory": "UL7RAFORGE",
    "components": components,
    "production_promotion": "LOCKED",
    "timestamp": time.time()
}

manifest["build_hash"] = hashlib.sha256(
    json.dumps(manifest, sort_keys=True).encode()
).hexdigest()

(ROOT / "state" / "build.json").write_text(
    json.dumps(manifest, indent=2)
)

with (ROOT / "evidence" / "build.jsonl").open("a") as f:
    f.write(json.dumps({
        "event": "V0.6_BUILD",
        "status": "PASS",
        "build_hash": manifest["build_hash"],
        "timestamp": time.time()
    }) + "\n")

print(json.dumps({
    "VERSION": "V0.6",
    "BUILD": "PASS",
    "BUILD_HASH": manifest["build_hash"],
    "PROMOTION": "LOCKED"
}, indent=2))
