#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

ASSURANCE="$ROOT/v10/ul7rastack/assurance"
LINEAGE="$ASSURANCE/runtime/lineage"
PURPLE_ROOT="$ASSURANCE/runtime/purple"
RECON="$ASSURANCE/runtime/verifier/independent/reconciliation"

mkdir -p "$RECON"

OUT="$RECON/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT"

export ROOT LINEAGE ASSURANCE PURPLE_ROOT RECON OUT

python3 - <<'PY'
import hashlib
import json
import os
import re
import sys
from pathlib import Path
from datetime import datetime, timezone

root = Path(os.environ["ROOT"]).resolve()
lineage = Path(os.environ["LINEAGE"]).resolve()
assurance = Path(os.environ["ASSURANCE"]).resolve()
purple_root = Path(os.environ["PURPLE_ROOT"]).resolve()
out = Path(os.environ["OUT"]).resolve()

def now():
    return datetime.now(timezone.utc).isoformat()

def read_json(path):
    try:
        return json.loads(Path(path).read_text())
    except Exception:
        return None

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def norm(v):
    if v is None:
        return None
    return str(v).strip().upper()

def status(obj, *keys):
    if not isinstance(obj, dict):
        return None
    for key in keys:
        if key in obj:
            return norm(obj[key])
    return None

def first_existing(paths):
    for p in paths:
        p = Path(p)
        if p.exists():
            return p.resolve()
    return None

def json_files(root_dir):
    if not root_dir.exists():
        return []
    return sorted(root_dir.rglob("*.json"), key=lambda p: str(p))

# ------------------------------------------------------------
# 1. S8 IMMUTABILITY
# ------------------------------------------------------------

s8_hash_file = assurance / "runtime/s8_baseline.sha256"

s8_pass = s8_hash_file.exists() and bool(
    s8_hash_file.read_text().strip()
)

# Also require S8 lineage manifest if available.
s8_manifest = lineage / "S8/manifest.json"
if s8_manifest.exists():
    s8_pass = s8_pass and isinstance(read_json(s8_manifest), dict)

# ------------------------------------------------------------
# 2. S9 CANDIDATE
# ------------------------------------------------------------

s9_root = lineage / "S9"

s9_evidence_files = sorted(
    s9_root.glob("*/evidence.json"),
    key=lambda p: str(p)
)

s9_release_files = sorted(
    s9_root.glob("*/release_gate.json"),
    key=lambda p: str(p)
)

s9_evidence_path = s9_evidence_files[-1] if s9_evidence_files else None
s9_evidence = read_json(s9_evidence_path) if s9_evidence_path else None

s9_pass = (
    s9_root.exists()
    and s9_evidence_path is not None
    and isinstance(s9_evidence, dict)
)

# ------------------------------------------------------------
# 3. AUTHORITATIVE PURPLE BINDING
# ------------------------------------------------------------

binding = root / (
    "v10/ul7rastack/assurance/runtime/"
    "verifier/independent/reconciliation/"
    "s9_purple_binding.json"
)

binding_obj = read_json(binding) if binding.exists() else None

purple_path = None
recorded_purple_hash = None
purple = None

if isinstance(binding_obj, dict):
    if norm(binding_obj.get("candidate_version")) == "S9":
        ref = binding_obj.get("evidence_path")
        recorded_purple_hash = binding_obj.get("evidence_sha256")

        if isinstance(ref, str):
            p = Path(ref)
            if not p.is_absolute():
                p = root / p
            if p.exists():
                purple_path = p.resolve()

# Never substitute "latest" Purple evidence when an authoritative
# binding exists but cannot be resolved.
if purple_path is None and binding.exists():
    purple_bound = False
else:
    purple_bound = False

if purple_path:
    purple = read_json(purple_path)

    if isinstance(purple, dict):
        computed_purple_hash = sha256(purple_path)
        purple_bound = (
            isinstance(recorded_purple_hash, str)
            and computed_purple_hash == recorded_purple_hash
        )
    else:
        computed_purple_hash = None
else:
    computed_purple_hash = None

# ------------------------------------------------------------
# 4. PURPLE STATUS
# ------------------------------------------------------------

if isinstance(purple, dict):
    red = status(purple, "red")
    blue = status(purple, "blue")
    regression = status(purple, "regression")
    purple_status = status(purple, "purple")
    purple_production = status(purple, "production")
    certification_claim = purple.get("certification_claim")
else:
    red = blue = regression = purple_status = None
    purple_production = None
    certification_claim = None

purple_pass = (
    purple_bound
    and red == "PASS"
    and blue == "PASS"
    and regression == "PASS"
    and purple_status == "PASS"
    and purple_production == "LOCKED"
    and certification_claim is False
)

# ------------------------------------------------------------
# 5. BUILD / TEST / REPRODUCIBILITY
#
# Do not accept missing values as PASS.
# Search existing MVIV lineage evidence only.
# ------------------------------------------------------------

mviv_runs = sorted(
    (lineage / "MVIV").glob("*"),
    key=lambda p: str(p)
)

build_values = []
test_values = []
repro_values = []

for run in mviv_runs:
    if not run.is_dir():
        continue

    for p in (
        run / "independent_decision.json",
        run / "reproducibility.json",
    ):
        obj = read_json(p)
        if isinstance(obj, dict):
            b = status(obj, "build", "build_status")
            t = status(obj, "test", "test_status")
            r = status(obj, "reproducibility", "status", "result")

            if b:
                build_values.append(b)
            if t:
                test_values.append(t)
            if r:
                repro_values.append(r)

    # Build logs may explicitly contain BUILD=PASS / TEST=PASS.
    for log in run.rglob("*.log"):
        try:
            text = log.read_text(errors="replace")
        except Exception:
            continue

        if re.search(r"\bBUILD\s*=\s*PASS\b", text):
            build_values.append("PASS")

        if re.search(r"\bTEST\s*=\s*PASS\b", text):
            test_values.append("PASS")

        if re.search(r"\bREPRODUCIBILITY\s*=\s*PASS\b", text):
            repro_values.append("PASS")

build_pass = "PASS" in build_values
test_pass = "PASS" in test_values

# Existing lineage reproducibility evidence.
repro_pass = False

for run in mviv_runs:
    p = run / "reproducibility.json"
    obj = read_json(p)

    if isinstance(obj, dict):
        value = status(obj, "status", "result", "reproducibility")
        if value == "PASS":
            repro_pass = True

if "PASS" in repro_values:
    repro_pass = True

# ------------------------------------------------------------
# 6. PROVENANCE
# ------------------------------------------------------------

provenance_pass = False

if isinstance(binding_obj, dict) and isinstance(purple, dict):
    bound_candidate = norm(binding_obj.get("candidate_version"))
    provenance_pass = (
        bound_candidate == "S9"
        and norm(purple.get("component")) == "PURPLE_TEAM"
        and norm(purple.get("authorization_scope"))
        == "LOCAL_UL7RAVERSE_TEST_ENVIRONMENT"
        and purple.get("external_targets") is False
    )

# Stronger candidate association if S9 evidence has an explicit
# purple hash/reference.
if isinstance(s9_evidence, dict):
    candidate_hash = None
    for key in (
        "purple_evidence_hash",
        "purpleEvidenceHash",
        "purple_evidence_sha256",
        "purpleEvidenceSha256",
    ):
        if isinstance(s9_evidence.get(key), str):
            candidate_hash = s9_evidence[key]
            break

    if candidate_hash:
        provenance_pass = provenance_pass and (
            candidate_hash == computed_purple_hash
            or candidate_hash == recorded_purple_hash
        )

# ------------------------------------------------------------
# 7. SINGLE AUTHORITATIVE SCHEMA GATE
#
# The actual schema file must exist and be valid JSON.
# We intentionally do NOT require the third-party jsonschema module.
# The Purple result has its own deterministic structural contract.
# ------------------------------------------------------------

schema = root / "assurance/evidence/schema.v1.json"

schema_exists = schema.exists()
schema_json_valid = False

if schema_exists:
    try:
        schema_obj = json.loads(schema.read_text())
        schema_json_valid = isinstance(schema_obj, dict)
    except Exception:
        schema_json_valid = False

# Validate the actual consumed Purple evidence against the fields
# required by the Purple evidence contract.
required_purple_fields = {
    "authorization_scope": str,
    "blue": str,
    "certification_claim": bool,
    "component": str,
    "evidence_hash": str,
    "external_targets": bool,
    "production": str,
    "purple": str,
    "red": str,
    "regression": str,
    "timestamp": str,
}

purple_shape_pass = False

if isinstance(purple, dict):
    purple_shape_pass = all(
        key in purple and isinstance(purple[key], typ)
        for key, typ in required_purple_fields.items()
    )

schema_pass = (
    schema_exists
    and schema_json_valid
    and purple_shape_pass
)

# ------------------------------------------------------------
# 8. RELEASE / PRODUCTION LOCK
# ------------------------------------------------------------

production_locked = True
certification_false = True

for p in s9_release_files[-1:]:
    obj = read_json(p)

    if isinstance(obj, dict):
        production = status(
            obj,
            "production",
            "production_status",
            "release"
        )

        if production and production not in (
            "LOCKED",
            "BLOCKED",
        ):
            production_locked = False

        if "certification_claim" in obj:
            certification_false = (
                obj["certification_claim"] is False
            )

if isinstance(s9_evidence, dict):
    if "production" in s9_evidence:
        production_locked = (
            norm(s9_evidence["production"]) == "LOCKED"
        )

    if "certification_claim" in s9_evidence:
        certification_false = (
            s9_evidence["certification_claim"] is False
        )

if isinstance(purple, dict):
    production_locked = production_locked and (
        norm(purple.get("production")) == "LOCKED"
    )

    certification_false = certification_false and (
        purple.get("certification_claim") is False
    )

# ------------------------------------------------------------
# 9. FINAL DECISION
# ------------------------------------------------------------

checks = {
    "S8": s8_pass,
    "S9": s9_pass,
    "BUILD": build_pass,
    "TEST": test_pass,
    "REPRODUCIBILITY": repro_pass,
    "RED": red == "PASS",
    "BLUE": blue == "PASS",
    "REGRESSION": regression == "PASS",
    "PURPLE": purple_status == "PASS",
    "PURPLE_EVIDENCE_BOUND": purple_bound,
    "PROVENANCE": provenance_pass,
    "SCHEMA": schema_pass,
    "PRODUCTION_LOCKED": production_locked,
    "CERTIFICATION_CLAIM_FALSE": certification_false,
}

all_local_checks = all(checks.values())

decision = "NEXT" if all_local_checks else "BLOCKED"

# External independence is NEVER promoted by this local script.
external_independence = "REQUIRED"

# ------------------------------------------------------------
# 10. MACHINE-READABLE RECORD
# ------------------------------------------------------------

record = {
    "component": "UL7RAFORGE_MVIV_RECONCILIATION",
    "version": "MVIV-RECON-2",
    "timestamp": now(),

    "baseline": "S8",
    "candidate": "S9",

    "checks": checks,

    "build": "PASS" if build_pass else "UNKNOWN",
    "test": "PASS" if test_pass else "UNKNOWN",
    "reproducibility": "PASS" if repro_pass else "UNKNOWN",

    "red": red or "UNKNOWN",
    "blue": blue or "UNKNOWN",
    "regression": regression or "UNKNOWN",
    "purple": purple_status or "UNKNOWN",

    "purple_evidence": {
        "path": str(purple_path) if purple_path else None,
        "recorded_sha256": recorded_purple_hash,
        "computed_sha256": computed_purple_hash,
        "bound": purple_bound,
    },

    "schema": {
        "path": str(schema),
        "exists": schema_exists,
        "json_valid": schema_json_valid,
        "purple_shape_valid": purple_shape_pass,
        "result": "PASS" if schema_pass else "FAIL",
    },

    "provenance": {
        "result": "PASS" if provenance_pass else "FAIL",
        "binding": str(binding) if binding.exists() else None,
        "candidate": "S9",
    },

    "decision": decision,
    "external_independence": external_independence,
    "production": "LOCKED",
    "certification_claim": False,

    "fail_closed": True,
}

record_path = out / "verification_record.json"
record_path.write_text(
    json.dumps(record, indent=2, sort_keys=True) + "\n"
)

# Canonical digest of the reconciliation record.
canonical = json.dumps(
    record,
    sort_keys=True,
    separators=(",", ":"),
).encode()

record_hash = hashlib.sha256(canonical).hexdigest()

(out / "verification_record.sha256").write_text(record_hash + "\n")

# ------------------------------------------------------------
# 11. TERMINAL OUTPUT
# ------------------------------------------------------------

def display(name, value):
    print(f"{name}={value}")

print("=" * 40)
print("UL7RAFORGE MVIV RECONCILIATION")
print("=" * 40)

display("S8", "IMMUTABLE/PASS" if s8_pass else "FAIL")
display("S9", "CANDIDATE" if s9_pass else "FAIL")
display("BUILD", "PASS" if build_pass else "UNKNOWN")
display("TEST", "PASS" if test_pass else "UNKNOWN")
display("REPRODUCIBILITY", "PASS" if repro_pass else "UNKNOWN")
display("RED", red or "UNKNOWN")
display("BLUE", blue or "UNKNOWN")
display("REGRESSION", regression or "UNKNOWN")
display("PURPLE", purple_status or "UNKNOWN")
display(
    "PURPLE_EVIDENCE_BOUND",
    "PASS" if purple_bound else "FAIL"
)
display(
    "PROVENANCE",
    "PASS" if provenance_pass else "FAIL"
)
display(
    "SCHEMA",
    "PASS" if schema_pass else "FAIL"
)
display("MVIV", decision)
display("EXTERNAL_INDEPENDENCE", external_independence)
display("PRODUCTION", "LOCKED")
display("EVIDENCE", str(record_path))
display("EVIDENCE_SHA256", record_hash)

print("=" * 40)

# Never unlock production. Never claim external independence.
if decision != "NEXT":
    sys.exit(1)
PY
