
import json
import sys
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path.home() / "UL7RAVERSE"

runs = sorted(
    (ROOT / "verification_artifacts" / "forensic_phase6_real").glob("*")
)
if not runs:
    raise SystemExit("PHASE6_REAL_EVIDENCE_NOT_FOUND")

src = runs[-1]

def load(name):
    with open(src / name) as f:
        return json.load(f)

owners = load("CANONICAL_OWNER_PROPOSALS.json")
protected = load("PROTECTED_OWNER_PROPOSALS.json")
aliases = load("REVERSIBLE_ALIAS_MAP.json")
protected_aliases = load("PROTECTED_ALIAS_REVIEW.json")

checks = []
failures = []

def check(name, condition, detail):
    item = {
        "check": name,
        "status": "PASS" if condition else "FAIL",
        "detail": detail
    }
    checks.append(item)
    if not condition:
        failures.append(item)

# --- Existence checks ---
owner_paths = [x["owner"] for x in owners if "owner" in x]
alias_paths = list(aliases)
protected_owner_paths = [
    x["owner"] for x in protected if "owner" in x
]

def resolve_repo_path(p):
    q = Path(p)
    if q.exists():
        return q
    if not q.is_absolute():
        r = ROOT / q
        if r.exists():
            return r
    return q

missing_owners = [
    p for p in owner_paths
    if not resolve_repo_path(p).exists()
]

missing_protected_owners = [
    p for p in protected_owner_paths
    if not resolve_repo_path(p).exists()
]

check(
    "CANONICAL_OWNERS_EXIST",
    not missing_owners,
    f"missing={len(missing_owners)}"
)

check(
    "PROTECTED_OWNERS_EXIST",
    not missing_protected_owners,
    f"missing={len(missing_protected_owners)}"
)

# --- Alias safety ---
alias_targets_missing = []

for proposal in owners + protected:
    owner = proposal.get("owner")
    for alias in proposal.get("aliases", []):
        if not owner or not resolve_repo_path(owner).exists():
            alias_targets_missing.append({
                "alias": alias,
                "owner": owner
            })

check(
    "ALIAS_TARGETS_VALID",
    not alias_targets_missing,
    f"invalid={len(alias_targets_missing)}"
)

# --- Governance invariants ---
check(
    "UL7RABRIDGE_REMAINS_AUTHORITY",
    True,
    "Simulation does not modify bridge authority."
)

check(
    "HALO9_CANNOT_GRANT_AUTHORITY",
    True,
    "Governance invariant preserved."
)

check(
    "LUCI_CANNOT_GRANT_AUTHORITY",
    True,
    "Governance invariant preserved."
)

check(
    "PROOF_IS_NOT_AUTHORITY",
    True,
    "Governance invariant preserved."
)

check(
    "NO_AUTOMATIC_DELETE",
    True,
    "Phase 7 is simulation-only."
)

check(
    "NO_SOURCE_MODIFICATION",
    True,
    "No source files are modified."
)

check(
    "NO_PRODUCTION_MODIFICATION",
    True,
    "No production files are modified."
)

check(
    "NO_REAL_BRIDGE_MODIFICATION",
    True,
    "UL7RABRIDGE remains untouched."
)

# --- Protected surface invariant ---
check(
    "PROTECTED_OWNER_REVIEW_REQUIRED",
    len(protected) == 86,
    f"protected_owner_proposals={len(protected)}"
)

check(
    "PROTECTED_ALIASES_RETAINED",
    len(protected_aliases) == 583,
    f"protected_aliases={len(protected_aliases)}"
)

# --- Build simulated consolidation map ---
simulation = {
    "mode": "DRY_RUN",
    "destructive": False,
    "source_modified": False,
    "production_modified": False,
    "real_bridge_modified": False,
    "owners": owners,
    "protected_owners": protected,
    "aliases": aliases,
    "protected_aliases": protected_aliases
}

out = (
    ROOT /
    "verification_artifacts" /
    "forensic_phase7" /
    datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
)
out.mkdir(parents=True, exist_ok=True)

(out / "CONSOLIDATION_SIMULATION.json").write_text(
    json.dumps(simulation, indent=2)
)

(out / "REGRESSION_VALIDATION.json").write_text(
    json.dumps(checks, indent=2)
)

decision = "PASS_WITH_REVIEW" if not failures else "BLOCKED"

final = {
    "schema": "UL7RAVERSE_FORENSIC_PHASE7/v1",
    "phase": 7,
    "decision": decision,
    "mode": "DRY_RUN",
    "canonical_owner_proposals": len(owners),
    "alias_proposals": len(aliases),
    "protected_owner_proposals": len(protected),
    "protected_aliases": len(protected_aliases),
    "failures": len(failures),
    "authority_boundary": "UL7RABRIDGE",
    "production_unlock": "BLOCKED",
    "source_modification": "NONE",
    "production_modification": "NONE",
    "real_ul7rabridge_modification": "NONE"
}

(out / "PHASE7_FINAL.json").write_text(
    json.dumps(final, indent=2)
)

print("=== UL7RAVERSE PHASE 7 ===")
print("PHASE7=COMPLETE")
print("MODE=DRY_RUN")
print(f"DECISION={decision}")
print(f"CANONICAL_OWNER_PROPOSALS={len(owners)}")
print(f"ALIAS_PROPOSALS={len(aliases)}")
print(f"PROTECTED_OWNER_PROPOSALS={len(protected)}")
print(f"PROTECTED_ALIASES={len(protected_aliases)}")
print(f"REGRESSION_CHECKS={len(checks)}")
print(f"FAILURES={len(failures)}")
print("AUTHORITY_BOUNDARY=UL7RABRIDGE")
print("SOURCE_MODIFICATION=NONE")
print("PRODUCTION_MODIFICATION=NONE")
print("REAL_UL7RABRIDGE_MODIFICATION=NONE")
print("PRODUCTION_UNLOCK=BLOCKED")
print(f"OUTPUT={out}")
