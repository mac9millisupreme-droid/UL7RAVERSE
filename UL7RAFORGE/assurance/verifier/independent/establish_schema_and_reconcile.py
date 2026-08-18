from pathlib import Path
import json, hashlib, subprocess, sys

ROOT = Path.cwd()

schema_dir = ROOT / "assurance/evidence"
schema_dir.mkdir(parents=True, exist_ok=True)

schema = {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": "ul7ra://assurance/evidence/schema.v1.json",
    "title": "UL7RAFORGE Evidence Bundle v1",
    "type": "object",
    "required": ["component", "timestamp", "production", "certification_claim"],
    "properties": {
        "component": {"type": "string"},
        "timestamp": {"type": "string"},
        "production": {"type": "string", "enum": ["LOCKED"]},
        "certification_claim": {"type": "boolean"},
        "evidence_hash": {
            "type": "string",
            "pattern": "^[0-9a-f]{64}$"
        },
        "authorization_scope": {"type": "string"},
        "red": {"type": "string"},
        "blue": {"type": "string"},
        "regression": {"type": "string"},
        "purple": {"type": "string"},
        "external_targets": {"type": "boolean"}
    },
    "additionalProperties": True
}

schema_path = schema_dir / "schema.v1.json"
schema_path.write_text(
    json.dumps(schema, indent=2, sort_keys=True) + "\n"
)

binding_path = (
    ROOT
    / "v10/ul7rastack/assurance/runtime/verifier/independent"
    / "reconciliation/s9_purple_binding.json"
)

if not binding_path.exists():
    print("BINDING=FAIL")
    sys.exit(1)

binding = json.loads(binding_path.read_text())

purple_path = Path(binding["evidence_path"])
if not purple_path.is_absolute():
    purple_path = ROOT / purple_path

if not purple_path.exists():
    print("PURPLE_EVIDENCE=FAIL")
    sys.exit(1)

purple = json.loads(purple_path.read_text())

actual_hash = hashlib.sha256(purple_path.read_bytes()).hexdigest()
expected_hash = binding.get("evidence_sha256")

errors = []

for field in schema["required"]:
    if field not in purple:
        errors.append("missing:" + field)

if purple.get("production") != "LOCKED":
    errors.append("production_not_locked")

if purple.get("certification_claim") is not False:
    errors.append("certification_claim_not_false")

if actual_hash != expected_hash:
    errors.append("evidence_hash_mismatch")

result = {
    "schema": str(schema_path.relative_to(ROOT)),
    "evidence": str(purple_path.relative_to(ROOT)),
    "computed_sha256": actual_hash,
    "recorded_sha256": expected_hash,
    "validation": "PASS" if not errors else "FAIL",
    "errors": errors
}

out = (
    ROOT
    / "v10/ul7rastack/assurance/runtime/verifier/independent"
    / "reconciliation/schema_validation.json"
)

out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")

print("SCHEMA_FILE=" + str(schema_path))
print("PURPLE_EVIDENCE=PASS")
print("PURPLE_SHA256=" + actual_hash)
print("SCHEMA_VALIDATION=" + result["validation"])

if errors:
    print("ERRORS=" + json.dumps(errors))
    sys.exit(1)

print("SCHEMA=PASS")
