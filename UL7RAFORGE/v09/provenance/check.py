import json
import hashlib
from pathlib import Path

root = Path(__file__).resolve().parents[1]
build = root.parent / "v06" / "state" / "build.json"

if not build.exists():
    raise SystemExit("PROVENANCE = FAIL: V0.6 build manifest missing")

data = json.loads(build.read_text())

required = ["version", "factory", "components", "build_hash"]

for field in required:
    if field not in data:
        raise SystemExit(f"PROVENANCE = FAIL: missing {field}")

result = {
    "gate": "PROVENANCE",
    "source": "V0.6_BUILD_MANIFEST",
    "manifest": str(build),
    "manifest_present": True,
    "source_version": data["version"],
    "factory": data["factory"],
    "component_count": len(data["components"])
}

result["evidence_hash"] = hashlib.sha256(
    json.dumps(result, sort_keys=True).encode()
).hexdigest()

(root / "state" / "provenance.json").write_text(
    json.dumps(result, indent=2)
)

print("PROVENANCE = PASS")
print("SOURCE = V0.6_BUILD_MANIFEST")
print("EVIDENCE HASH =", result["evidence_hash"])
