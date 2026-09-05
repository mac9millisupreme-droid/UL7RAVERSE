#!/usr/bin/env python3
import hashlib
import json
import sys
from pathlib import Path

REQUIRED = {
    "schema_version",
    "candidate",
    "repository_commit",
    "evidence_sha256",
    "verifier_env_id",
    "credential_domain",
    "decision",
    "independence",
    "attestation_key_id",
    "signature",
    "timestamp",
}

def fail(reason):
    print("EXTERNAL_ATTESTATION_RECONCILIATION=BLOCKED")
    print(f"REASON={reason}")
    raise SystemExit(1)

if len(sys.argv) != 4:
    fail("USAGE")

attestation_path = Path(sys.argv[1])
evidence_path = Path(sys.argv[2])
expected_commit = sys.argv[3]

if not attestation_path.is_file():
    fail("ATTESTATION_NOT_FOUND")

if not evidence_path.is_file():
    fail("EVIDENCE_NOT_FOUND")

try:
    attestation = json.loads(attestation_path.read_text())
except Exception:
    fail("INVALID_ATTESTATION_JSON")

missing = sorted(REQUIRED - set(attestation))
if missing:
    fail("MISSING_FIELDS:" + ",".join(missing))

actual_hash = hashlib.sha256(evidence_path.read_bytes()).hexdigest()

if actual_hash != attestation["evidence_sha256"]:
    fail("EVIDENCE_HASH_MISMATCH")

if expected_commit != attestation["repository_commit"]:
    fail("COMMIT_MISMATCH")

if attestation["candidate"] != "S9":
    fail("WRONG_CANDIDATE")

if attestation["independence"] != "PROVEN":
    fail("INDEPENDENCE_NOT_PROVEN")

if attestation["decision"] != "PASS":
    fail("EXTERNAL_DECISION_NOT_PASS")

for field in (
    "verifier_env_id",
    "credential_domain",
    "attestation_key_id",
    "signature",
):
    if not attestation[field]:
        fail(f"MISSING_{field.upper()}")

print("========================================")
print("UL7RA EXTERNAL ATTESTATION RECONCILIATION")
print("========================================")
print("ATTESTATION_SCHEMA=PASS")
print("EVIDENCE_HASH=PASS")
print("COMMIT_BINDING=PASS")
print("CANDIDATE=S9")
print("INDEPENDENCE=PROVEN")
print("EXTERNAL_DECISION=PASS")
print("SIGNATURE=PRESENT")
print("DECISION=PASS")
print("PRODUCTION=ELIGIBLE_FOR_FINAL_RECONCILIATION")
print("========================================")
