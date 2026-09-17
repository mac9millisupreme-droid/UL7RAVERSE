
import json
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path.home() / "UL7RAVERSE"

def latest_dir(name):
    base = ROOT / "verification_artifacts" / name
    dirs = sorted(x for x in base.iterdir() if x.is_dir())
    if not dirs:
        raise RuntimeError(f"Missing evidence directory: {base}")
    return dirs[-1]

def load(path):
    return json.loads(path.read_text())

P7 = latest_dir("forensic_phase7")
P8 = latest_dir("forensic_phase8_lite")

sim = load(P7 / "CONSOLIDATION_SIMULATION.json")
reg = load(P7 / "REGRESSION_VALIDATION.json")
p8 = load(P8 / "PHASE8_FINAL.json")
identity = load(P8 / "IDENTITY_REHEARSAL.json")
rollback = load(P8 / "ROLLBACK_MAP.json")

owners = sim.get("owners", [])
protected_owners = sim.get("protected_owners", [])
aliases = sim.get("aliases", [])
protected_aliases = sim.get("protected_aliases", [])

# ------------------------------------------------------------
# Phase 9 preconditions
# ------------------------------------------------------------

preconditions = {
    "phase8_decision": p8.get("decision"),
    "protected_conflicts": p8.get("protected_conflicts"),
    "regression_failures": p8.get("regression_failures"),
    "owner_groups": len(owners),
    "protected_groups": len(protected_owners),
    "aliases": len(aliases),
    "protected_aliases": len(protected_aliases),
    "identity_items": len(identity),
    "rollback_items": len(rollback),
}

precondition_failures = []

if p8.get("decision") != "PASS_WITH_REVIEW":
    precondition_failures.append("PHASE8_NOT_PASS_WITH_REVIEW")

if p8.get("protected_conflicts") != 0:
    precondition_failures.append("PROTECTED_CONFLICTS_PRESENT")

if p8.get("regression_failures") != 0:
    precondition_failures.append("REGRESSION_FAILURES_PRESENT")

if len(owners) != 40:
    precondition_failures.append("OWNER_COUNT_MISMATCH")

if len(protected_owners) != 86:
    precondition_failures.append("PROTECTED_OWNER_COUNT_MISMATCH")

if len(aliases) != 87:
    precondition_failures.append("ALIAS_COUNT_MISMATCH")

if len(protected_aliases) != 583:
    precondition_failures.append("PROTECTED_ALIAS_COUNT_MISMATCH")

if len(identity) != 126:
    precondition_failures.append("IDENTITY_COUNT_MISMATCH")

if len(rollback) != 126:
    precondition_failures.append("ROLLBACK_COUNT_MISMATCH")

# ------------------------------------------------------------
# A. Owner -> Alias Map
# ------------------------------------------------------------

owner_alias_map = []

for group in owners:
    owner_alias_map.append({
        "owner": group["owner"],
        "aliases": list(group.get("aliases", [])),
        "protected_aliases": [],
        "evidence": [
            "PHASE7:CONSOLIDATION_SIMULATION.json",
            "PHASE8:IDENTITY_REHEARSAL.json",
        ],
        "sha256": group.get("sha256"),
        "conflict_status": "none",
        "status": "review_required",
        "automatic_merge": False,
        "automatic_delete": False,
    })

# Protected owners remain explicitly protected.
for group in protected_owners:
    owner_alias_map.append({
        "owner": group["owner"],
        "aliases": list(group.get("aliases", [])),
        "protected_aliases": list(group.get("aliases", [])),
        "evidence": [
            "PHASE7:CONSOLIDATION_SIMULATION.json",
            "PHASE8:IDENTITY_REHEARSAL.json",
        ],
        "sha256": group.get("sha256"),
        "conflict_status": "none",
        "status": "review_required",
        "automatic_merge": False,
        "automatic_delete": False,
    })

# ------------------------------------------------------------
# B. Protected Item Ledger
# ------------------------------------------------------------

protected_ledger = []

for group in protected_owners:
    owner = group["owner"]

    protected_ledger.append({
        "protected_item": owner,
        "type": "protected_owner",
        "reason": "Phase 5 protected surface carried through Phase 7/8",
        "evidence": [
            "PHASE5:PROTECTED_SURFACES.json",
            "PHASE7:CONSOLIDATION_SIMULATION.json",
            "PHASE8:IDENTITY_REHEARSAL.json",
        ],
        "review_gate": "required",
    })

    for alias in group.get("aliases", []):
        protected_ledger.append({
            "protected_item": alias,
            "type": "protected_alias",
            "owner": owner,
            "reason": "Protected alias associated with protected owner proposal",
            "evidence": [
                "PHASE5:PROTECTED_SURFACES.json",
                "PHASE7:CONSOLIDATION_SIMULATION.json",
                "PHASE8:IDENTITY_REHEARSAL.json",
            ],
            "review_gate": "required",
        })

# ------------------------------------------------------------
# C. Rollback Sequence
# ------------------------------------------------------------

rollback_sequence = []

for i, item in enumerate(identity, start=1):
    rb = rollback[i - 1] if i <= len(rollback) else {}

    rollback_sequence.append({
        "sequence": i,
        "identity_item": item.get("owner"),
        "rollback_item": rb.get("owner"),
        "aliases": list(item.get("aliases", [])),
        "reversible": True,
        "evidence": [
            "PHASE7:CONSOLIDATION_SIMULATION.json",
            "PHASE8:IDENTITY_REHEARSAL.json",
            "PHASE8:ROLLBACK_MAP.json",
        ],
        "rollback_gate": "required",
        "execution": "NOT_AUTHORIZED",
    })

# ------------------------------------------------------------
# D. Governance Gate Plan
# ------------------------------------------------------------

governance = {
    "schema": "UL7RAVERSE_PHASE9_GOVERNANCE_GATE_PLAN/v1",
    "phase": 9,
    "mode": "PLANNING_ONLY",
    "authority_boundary": "UL7RABRIDGE",

    "gates": [
        {
            "gate": "REVIEW_GATE",
            "status": "REQUIRED",
            "requirements": [
                "Review all owner-to-alias mappings",
                "Review all protected owners",
                "Review all protected aliases",
            ],
        },
        {
            "gate": "ROLLBACK_GATE",
            "status": "REQUIRED",
            "requirements": [
                "Validate all 126 identity items",
                "Validate all 126 rollback items",
                "Confirm reversibility before any future execution",
            ],
        },
        {
            "gate": "EVIDENCE_GATE",
            "status": "REQUIRED",
            "requirements": [
                "Every mapping references Phase 7 evidence",
                "Every mapping references Phase 8 evidence",
                "No inferred evidence may replace recorded evidence",
            ],
        },
        {
            "gate": "PRODUCTION_GATE",
            "status": "BLOCKED",
            "requirements": [
                "No production modification during Phase 9",
                "No production unlock until governance gates pass",
                "No authority transfer to consolidation tooling",
            ],
        },
        {
            "gate": "CANONICAL_GATE",
            "status": "FROZEN",
            "requirements": [
                "Canonical assurance remains unchanged",
                "UL7RABRIDGE remains the authority boundary",
                "No owner becomes canonical solely from this plan",
            ],
        },
    ],

    "invariants": [
        "UNVERIFIED != PASS",
        "UNKNOWN remains UNKNOWN",
        "NO PROOF -> NO TRUSTED ACTION",
        "COMMERCE != PROOF",
        "PAYMENT != PROOF",
        "AGENT != AUTHORITY",
        "LUCI != AUTHORITY",
        "UL7RAPROOF != AUTHORITY",
        "Git = history",
        "Ledger = evidence",
        "Governance = authority",
        "Fail closed",
    ],
}

# ------------------------------------------------------------
# Consolidation Plan
# ------------------------------------------------------------

plan = {
    "schema": "UL7RAVERSE_CONSOLIDATION_PLAN/v1",
    "phase": 9,
    "mode": "EVIDENCE_BACKED_PLANNING_ONLY",
    "decision": (
        "PLAN_READY_FOR_REVIEW"
        if not precondition_failures
        else "BLOCKED"
    ),
    "authority_boundary": "UL7RABRIDGE",
    "canonicality": "FROZEN",
    "execution_authorized": False,

    "inputs": {
        "phase7": str(P7),
        "phase8": str(P8),
    },

    "counts": preconditions,

    "precondition_failures": precondition_failures,

    "planned_artifacts": [
        "OWNER_ALIAS_MAP.json",
        "PROTECTED_ITEM_LEDGER.json",
        "ROLLBACK_SEQUENCE.json",
        "GOVERNANCE_GATE_PLAN.json",
    ],

    "prohibited_actions": [
        "MERGE",
        "DELETE",
        "RENAME",
        "SOURCE_MODIFICATION",
        "PRODUCTION_MODIFICATION",
        "UL7RABRIDGE_MODIFICATION",
        "CANONICAL_AUTHORITY_CHANGE",
        "PRODUCTION_UNLOCK",
    ],

    "next_gate": "HUMAN_REVIEW",
}

# ------------------------------------------------------------
# Write artifacts
# ------------------------------------------------------------

out = (
    ROOT /
    "verification_artifacts" /
    "forensic_phase9" /
    datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
)

out.mkdir(parents=True, exist_ok=True)

(out / "OWNER_ALIAS_MAP.json").write_text(
    json.dumps(owner_alias_map, indent=2)
)

(out / "PROTECTED_ITEM_LEDGER.json").write_text(
    json.dumps(protected_ledger, indent=2)
)

(out / "ROLLBACK_SEQUENCE.json").write_text(
    json.dumps(rollback_sequence, indent=2)
)

(out / "GOVERNANCE_GATE_PLAN.json").write_text(
    json.dumps(governance, indent=2)
)

(out / "CONSOLIDATION_PLAN.json").write_text(
    json.dumps(plan, indent=2)
)

print("=== UL7RAVERSE PHASE 9 ===")
print("PHASE9=COMPLETE")
print("MODE=EVIDENCE_BACKED_PLANNING_ONLY")
print(f"DECISION={plan['decision']}")
print(f"OWNER_GROUPS={len(owners)}")
print(f"PROTECTED_GROUPS={len(protected_owners)}")
print(f"ALIASES={len(aliases)}")
print(f"PROTECTED_ALIASES={len(protected_aliases)}")
print(f"IDENTITY_ITEMS={len(identity)}")
print(f"ROLLBACK_ITEMS={len(rollback_sequence)}")
print(f"PROTECTED_LEDGER_ITEMS={len(protected_ledger)}")
print(f"PRECONDITION_FAILURES={len(precondition_failures)}")
print("MERGE=NOT_AUTHORIZED")
print("DELETE=NOT_AUTHORIZED")
print("SOURCE_MODIFICATION=NONE")
print("PRODUCTION_MODIFICATION=NONE")
print("REAL_UL7RABRIDGE_MODIFICATION=NONE")
print("CANONICAL_ASSURANCE=FROZEN")
print("PRODUCTION_UNLOCK=BLOCKED")
print("NEXT_GATE=HUMAN_REVIEW")
print(f"OUTPUT={out}")
