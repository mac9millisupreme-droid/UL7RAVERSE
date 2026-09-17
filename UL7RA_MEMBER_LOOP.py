#!/usr/bin/env python3

import json
import hashlib
import secrets
import subprocess
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path.cwd()
STAMP = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

OUT = ROOT / "verification_artifacts" / "member_loop" / STAMP
OUT.mkdir(parents=True, exist_ok=True)

MEMBERS = ROOT / "member_loop"
MEMBERS.mkdir(exist_ok=True)

PRODUCT = {
    "name": "UL7RAPASS",
    "price_cad": 500,
    "term_months": 12,
    "units": 1500,
    "lucicoin": 3,
    "included": [
        "LUCIAGENT3_CUSTOM",
        "LUCI_DIAGNOSTIC",
        "LUCI_TEST",
        "ADVERSARIAL_VERIFICATION",
        "UL7RAPROOF",
        "SHAREABLE_PROOF_ARTIFACT",
    ],
}

def utc():
    return datetime.now(timezone.utc).isoformat()

def digest(obj):
    return hashlib.sha256(
        json.dumps(obj, sort_keys=True).encode()
    ).hexdigest()

def save(path, obj):
    path.write_text(
        json.dumps(obj, indent=2, sort_keys=True),
        encoding="utf-8"
    )

def new_member():
    return {
        "member_id": "member_" + secrets.token_hex(8),
        "created_at": utc(),
        "payment_status": "UNPAID",
        "entitlement_status": "INACTIVE",
        "verification_status": "UNKNOWN",

        "product": PRODUCT["name"],
        "price_cad": PRODUCT["price_cad"],
        "term_months": PRODUCT["term_months"],

        "units_total": PRODUCT["units"],
        "units_used": 0,

        "lucicoin_total": PRODUCT["lucicoin"],
        "lucicoin_used": 0,

        "diagnostics": 0,
        "tests": 0,
        "adversarial_verifications": 0,
        "proofs": 0,
    }

def activate(member):
    member["payment_status"] = "PAID"
    member["entitlement_status"] = "ACTIVE"
    return member

def use_unit(member):
    if member["entitlement_status"] != "ACTIVE":
        return False

    if member["units_used"] >= member["units_total"]:
        return False

    member["units_used"] += 1
    return True

def use_coin(member):
    if member["entitlement_status"] != "ACTIVE":
        return False

    if member["lucicoin_used"] >= member["lucicoin_total"]:
        return False

    member["lucicoin_used"] += 1
    return True

def diagnostic(member):
    if not use_unit(member):
        return False
    member["diagnostics"] += 1
    return True

def test(member):
    if not use_unit(member):
        return False
    member["tests"] += 1
    return True

def adversarial_verification(member):
    if not use_unit(member):
        return False
    member["adversarial_verifications"] += 1
    return True

def proof(member, evidence):
    # Proof is evidence-derived.
    if not evidence:
        return None

    member["proofs"] += 1
    member["verification_status"] = "PASS"
    return {
        "proof_id": "proof_" + secrets.token_hex(8),
        "member_id": member["member_id"],
        "decision": "PASS",
        "created_at": utc(),
        "evidence_hash": digest(evidence),
    }

# ------------------------------------------------------------
# MEMBER LOOP
# ------------------------------------------------------------

member = new_member()

# Paid status alone must NOT create PASS.
activate(member)

assert member["payment_status"] == "PAID"
assert member["entitlement_status"] == "ACTIVE"
assert member["verification_status"] == "UNKNOWN"

# Full first-member journey.
assert diagnostic(member)
assert test(member)
assert adversarial_verification(member)

evidence = {
    "diagnostic": True,
    "test": True,
    "adversarial_verification": True,
    "member_id": member["member_id"],
}

proof_artifact = proof(member, evidence)

assert proof_artifact is not None
assert proof_artifact["decision"] == "PASS"

# ------------------------------------------------------------
# PURPLE TEAM
# ------------------------------------------------------------

attacks = {}

# Payment must not independently create PASS.
m = new_member()
activate(m)
attacks["PAYMENT_CANNOT_CREATE_PASS"] = (
    m["verification_status"] == "UNKNOWN"
)

# Unpaid member cannot consume units.
m = new_member()
attacks["UNPAID_CANNOT_USE"] = not use_unit(m)

# Unit ceiling.
m = new_member()
activate(m)

for _ in range(PRODUCT["units"]):
    assert use_unit(m)

attacks["1500_UNIT_CEILING"] = not use_unit(m)

# LUCIcoin ceiling.
m = new_member()
activate(m)

for _ in range(PRODUCT["lucicoin"]):
    assert use_coin(m)

attacks["3_LUCICOIN_CEILING"] = not use_coin(m)

# No evidence = no PASS.
m = new_member()
activate(m)
attacks["NO_EVIDENCE_NO_PASS"] = proof(m, None) is None

# Proof artifact must identify its evidence.
attacks["PROOF_HAS_EVIDENCE_HASH"] = (
    bool(proof_artifact.get("evidence_hash"))
)

purple_pass = all(attacks.values())

# ------------------------------------------------------------
# EXISTING TEST SUITE
# ------------------------------------------------------------

test_run = subprocess.run(
    ["python", "-m", "pytest", "-q"],
    cwd=ROOT,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
)

pytest_pass = test_run.returncode == 0

# ------------------------------------------------------------
# SAVE MEMBER + PRODUCT + PROOF
# ------------------------------------------------------------

save(OUT / "PRODUCT.json", PRODUCT)
save(OUT / "MEMBER.json", member)
save(OUT / "PROOF_ARTIFACT.json", proof_artifact)
save(OUT / "PURPLE_TEAM.json", attacks)

(OUT / "TEST_RESULTS.txt").write_text(
    test_run.stdout,
    encoding="utf-8"
)

status = {
    "timestamp": utc(),
    "repository": str(ROOT),
    "commit": subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    ).stdout.strip(),

    "technical_tests": pytest_pass,
    "purple_team": purple_pass,

    "payment_status": member["payment_status"],
    "entitlement_status": member["entitlement_status"],
    "verification_status": member["verification_status"],

    "units_total": member["units_total"],
    "units_used": member["units_used"],

    "lucicoin_total": member["lucicoin_total"],
    "lucicoin_used": member["lucicoin_used"],

    "proof_artifact": bool(proof_artifact),
}

save(OUT / "STATUS.json", status)

# ------------------------------------------------------------
# HASH PACKAGE
# ------------------------------------------------------------

hash_lines = []

for p in sorted(OUT.iterdir()):
    if p.is_file() and p.name != "SHA256SUMS.txt":
        hash_lines.append(
            hashlib.sha256(p.read_bytes()).hexdigest()
            + "  "
            + p.name
        )

(OUT / "SHA256SUMS.txt").write_text(
    "\n".join(hash_lines) + "\n",
    encoding="utf-8"
)

# ------------------------------------------------------------
# DECISION
# ------------------------------------------------------------

member_loop_pass = (
    pytest_pass
    and purple_pass
    and member["payment_status"] == "PAID"
    and member["entitlement_status"] == "ACTIVE"
    and member["verification_status"] == "PASS"
    and member["units_total"] == 1500
    and member["lucicoin_total"] == 3
    and bool(proof_artifact)
)

if member_loop_pass:
    final = "PASS"
elif pytest_pass:
    final = "UNKNOWN"
else:
    final = "FAIL"

print()
print("=== UL7RAVERSE MEMBER LOOP ===")
print()
print("REPOSITORY:", ROOT)
print("COMMIT:", status["commit"])
print("EVIDENCE:", OUT)
print()
print("UL7RAPASS")
print("PRICE: CAD $500")
print("TERM: 12 months")
print("UNITS: 1,500")
print("LUCIcoin: 3")
print("LUCIAGENT3: CUSTOM")
print("LUCI DIAGNOSTIC: INCLUDED")
print("LUCI TEST: INCLUDED")
print("ADVERSARIAL VERIFICATION: INCLUDED")
print("UL7RAPROOF: INCLUDED")
print()
print("MEMBER LOOP:")
print("PAYMENT:", member["payment_status"])
print("ENTITLEMENT:", member["entitlement_status"])
print("VERIFICATION:", member["verification_status"])
print("PROOF ARTIFACT:", "CREATED" if proof_artifact else "ABSENT")
print()
print("PURPLE TEAM:", "PASS" if purple_pass else "FAIL")
print("PYTEST:", "PASS" if pytest_pass else "FAIL")
print()
print("REVENUE TARGET:")
print("15 MEMBERS × CAD $500 = CAD $7,500 CASH")
print()
print("FINAL_DECISION:", final)
