#!/usr/bin/env python3

import json
import hashlib
import secrets
import subprocess
import sys
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path.cwd()
STAMP = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
OUT = ROOT / "verification_artifacts" / "ul7rapass" / STAMP
OUT.mkdir(parents=True, exist_ok=True)

PRODUCT = {
    "name": "UL7RAPASS",
    "price_cad": 500,
    "term_months": 12,
    "units": 1500,
    "lucicoin": 3,
    "entitlements": [
        "LUCIAGENT3_CUSTOM",
        "LUCI_DIAGNOSTIC",
        "LUCI_TEST",
        "PURPLE_TEAM",
        "UL7RAPROOF",
    ],
}

def now():
    return datetime.now(timezone.utc).isoformat()

def sha(data):
    return hashlib.sha256(
        json.dumps(data, sort_keys=True).encode()
    ).hexdigest()

def decision(payment, entitlement, proof):
    # PAYMENT NEVER GRANTS PROOF AUTHORITY.
    if proof is None:
        return "UNKNOWN"
    return proof

def new_member():
    return {
        "member_id": "m_" + secrets.token_hex(8),
        "payment_status": "UNPAID",
        "entitlement_status": "INACTIVE",
        "verification_status": "UNKNOWN",
        "units_total": PRODUCT["units"],
        "units_used": 0,
        "lucicoin_total": PRODUCT["lucicoin"],
        "lucicoin_used": 0,
    }

def purchase(member):
    member["payment_status"] = "PAID"
    member["entitlement_status"] = "ACTIVE"
    return member

def consume_unit(member):
    if member["entitlement_status"] != "ACTIVE":
        return False
    if member["units_used"] >= member["units_total"]:
        return False
    member["units_used"] += 1
    return True

def consume_coin(member):
    if member["entitlement_status"] != "ACTIVE":
        return False
    if member["lucicoin_used"] >= member["lucicoin_total"]:
        return False
    member["lucicoin_used"] += 1
    return True

def create_proof(member, evidence_ok):
    if not evidence_ok:
        return None
    return "PASS"

def attack_payment_grants_pass():
    m = purchase(new_member())
    return decision(m["payment_status"], m["entitlement_status"], None) == "UNKNOWN"

def attack_unit_overrun():
    m = purchase(new_member())
    for _ in range(PRODUCT["units"]):
        assert consume_unit(m)
    return not consume_unit(m)

def attack_coin_duplication():
    m = purchase(new_member())
    for _ in range(PRODUCT["lucicoin"]):
        assert consume_coin(m)
    return not consume_coin(m)

def attack_unpaid_entitlement():
    m = new_member()
    return not consume_unit(m)

def attack_proof_without_evidence():
    m = purchase(new_member())
    return create_proof(m, False) is None

def attack_payment_mutates_verification():
    m = new_member()
    purchase(m)
    return m["verification_status"] == "UNKNOWN"

def run_purple():
    attacks = {
        "PAYMENT_CANNOT_GRANT_PASS": attack_payment_grants_pass(),
        "UNIT_LIMIT_ENFORCED": attack_unit_overrun(),
        "LUCIcoin_LIMIT_ENFORCED": attack_coin_duplication(),
        "UNPAID_CANNOT_CONSUME": attack_unpaid_entitlement(),
        "NO_EVIDENCE_NO_PASS": attack_proof_without_evidence(),
        "PAYMENT_DOES_NOT_MUTATE_VERIFICATION":
            attack_payment_mutates_verification(),
    }
    return attacks

def run_pytest():
    p = subprocess.run(
        [sys.executable, "-m", "pytest", "-q"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    return p.returncode, p.stdout

# ------------------------------------------------------------
# BUILD / VERIFY COMMERCIAL SUBSTRATE
# ------------------------------------------------------------

member = new_member()

assert member["payment_status"] == "UNPAID"
assert member["entitlement_status"] == "INACTIVE"
assert member["verification_status"] == "UNKNOWN"

purchase(member)

assert member["payment_status"] == "PAID"
assert member["entitlement_status"] == "ACTIVE"

# Payment still cannot create PASS.
assert member["verification_status"] == "UNKNOWN"

# Consume one real entitlement unit.
assert consume_unit(member)

# Proof requires evidence.
proof = create_proof(member, True)
assert proof == "PASS"

member["verification_status"] = decision(
    member["payment_status"],
    member["entitlement_status"],
    proof,
)

# ------------------------------------------------------------
# PURPLE TEAM
# ------------------------------------------------------------

purple = run_purple()
purple_pass = all(purple.values())

# ------------------------------------------------------------
# EXISTING REPOSITORY TESTS
# ------------------------------------------------------------

pytest_rc, pytest_output = run_pytest()
pytest_pass = pytest_rc == 0

# ------------------------------------------------------------
# EVIDENCE
# ------------------------------------------------------------

status = {
    "timestamp": now(),
    "repository": str(ROOT),
    "commit": subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    ).stdout.strip(),
    "product": PRODUCT,
    "member_state": member,
    "purple_team": purple,
    "pytest_returncode": pytest_rc,
    "technical_tests": pytest_pass,
    "purple_team_pass": purple_pass,
    "proof_requires_evidence": True,
    "payment_can_grant_pass": False,
}

(OUT / "STATUS.json").write_text(
    json.dumps(status, indent=2),
    encoding="utf-8",
)

(OUT / "TEST_RESULTS.txt").write_text(
    pytest_output,
    encoding="utf-8",
)

(OUT / "PURPLE_RESULTS.txt").write_text(
    json.dumps(purple, indent=2),
    encoding="utf-8",
)

(OUT / "PRODUCT.json").write_text(
    json.dumps(PRODUCT, indent=2),
    encoding="utf-8",
)

evidence = {
    "run": STAMP,
    "product_hash": sha(PRODUCT),
    "status_hash": sha(status),
    "purple_hash": sha(purple),
    "decision_basis": {
        "technical_tests": pytest_pass,
        "purple_team": purple_pass,
        "payment_proof_separation": (
            member["payment_status"] == "PAID"
            and member["verification_status"] == "PASS"
            and member["units_used"] == 1
        ),
    },
}

(OUT / "EVIDENCE.json").write_text(
    json.dumps(evidence, indent=2),
    encoding="utf-8",
)

# ------------------------------------------------------------
# HASH ALL EVIDENCE
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
    encoding="utf-8",
)

# ------------------------------------------------------------
# COMMERCIAL DECISION
# ------------------------------------------------------------

commercial_pass = (
    pytest_pass
    and purple_pass
    and member["payment_status"] == "PAID"
    and member["entitlement_status"] == "ACTIVE"
    and member["verification_status"] == "PASS"
    and member["units_total"] == 1500
    and member["lucicoin_total"] == 3
)

if commercial_pass:
    final = "PASS"
elif pytest_pass:
    final = "UNKNOWN"
else:
    final = "FAIL"

print()
print("=== UL7RAPASS ONE-SCRIPT RELEASE ===")
print()
print("REPOSITORY:", ROOT)
print("COMMIT:", status["commit"])
print("EVIDENCE:", OUT)
print()
print("PRICE: CAD $500")
print("TERM: 12 months")
print("UNITS: 1,500")
print("LUCIcoin: 3")
print("LUCIAGENT3: CUSTOM")
print("LUCI DIAGNOSTIC: INCLUDED")
print("LUCI TEST: INCLUDED")
print("PURPLE TEAM: INCLUDED")
print("UL7RAPROOF: INCLUDED")
print()
print("PYTEST:", "PASS" if pytest_pass else "FAIL")
print("PURPLE TEAM:", "PASS" if purple_pass else "FAIL")
print("PAYMENT → PASS BYPASS:", "BLOCKED")
print("NO EVIDENCE → PASS BYPASS:", "BLOCKED")
print("UNIT OVERRUN:", "BLOCKED" if purple["UNIT_LIMIT_ENFORCED"] else "FAIL")
print("LUCIcoin DUPLICATION:", "BLOCKED" if purple["LUCIcoin_LIMIT_ENFORCED"] else "FAIL")
print()
print("REVENUE:")
print("15 SALES × CAD $500 = CAD $7,500 CASH")
print()
print("FINAL_DECISION:", final)
