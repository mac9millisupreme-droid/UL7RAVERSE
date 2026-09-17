import json
import sys
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path.home() / "UL7RAVERSE"
SRC = ROOT / "verification_artifacts" / "forensic_phase5" / "20260915T003024Z"

if not SRC.exists():
    raise SystemExit(f"PHASE5_EVIDENCE_NOT_FOUND={SRC}")

def load(name):
    p = SRC / name
    with p.open() as f:
        return json.load(f)

duplicates = load("CONFIRMED_DUPLICATES.json")
normalized = load("NORMALIZED_DUPLICATE_GROUPS.json")
protected = load("PROTECTED_SURFACES.json")
authority = load("AUTHORITY_SURFACES.json")
proof = load("PROOF_SURFACES.json")
inventory = load("SOURCE_FILE_INVENTORY.json")

protected_paths = {
    str(x.get("path"))
    for x in protected
    if isinstance(x, dict) and x.get("path")
}

authority_paths = {
    str(x.get("path"))
    for x in authority
    if isinstance(x, dict) and x.get("path")
}

proof_paths = {
    str(x.get("path"))
    for x in proof
    if isinstance(x, dict) and x.get("path")
}

inventory_paths = {
    str(x.get("path"))
    for x in inventory
    if isinstance(x, dict) and x.get("path")
}

def rank(path):
    p = str(path)
    l = p.lower()

    score = 0

    # Prefer actual source over generated evidence.
    if "verification_artifacts" in l:
        score -= 1000

    if any(x in l for x in ("/tests/", "/test/", "_test.", "test_")):
        score -= 300

    if any(x in l for x in ("legacy", "deprecated", "archive", "backup")):
        score -= 200

    if any(x in l for x in ("experimental", "prototype", "scratch")):
        score -= 150

    # Prefer canonical naming.
    if "ul7ra4orge" in l:
        score += 100
    if "ul7raforge" in l:
        score += 50

    # Prefer shorter, cleaner source paths.
    score -= len(p) / 10000

    return score

owners = []
unresolved = []
aliases = []
protected_owner_proposals = []
protected_aliases = []

for group in duplicates:
    paths = group.get("paths", [])

    if not isinstance(paths, list) or len(paths) < 2:
        unresolved.append({
            "group": group,
            "reason": "INSUFFICIENT_PATHS"
        })
        continue

    paths = [str(p) for p in paths]

    protected_group = any(
        p in protected_paths or
        p in authority_paths or
        p in proof_paths
        for p in paths
    )

    ranked = sorted(paths, key=lambda p: (-rank(p), p))
    owner = ranked[0]
    alias_list = ranked[1:]

    proposal = {
        "sha256": group.get("sha256"),
        "owner": owner,
        "aliases": alias_list,
        "members": ranked,
        "evidence": "CONFIRMED_EXACT_DUPLICATE",
        "reversible": True,
        "automatic_merge": False,
        "automatic_delete": False,
        "protected": protected_group
    }

    if protected_group:
        protected_owner_proposals.append(proposal)
        protected_aliases.extend(alias_list)
    else:
        owners.append(proposal)
        aliases.extend(alias_list)

out = (
    ROOT /
    "verification_artifacts" /
    "forensic_phase6_real" /
    datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
)
out.mkdir(parents=True, exist_ok=True)

result = {
    "schema": "UL7RAVERSE_FORENSIC_PHASE6_REAL/v1",
    "phase": 6,
    "decision": "REVIEW_REQUIRED",
    "canonicality": "PARTIALLY_RESOLVED",
    "authority_boundary": "UL7RABRIDGE",
    "production_unlock": "BLOCKED",
    "source_modification": "NONE",
    "production_modification": "NONE",
    "real_ul7rabridge_modification": "NONE",
    "input": {
        "confirmed_duplicate_groups": len(duplicates),
        "normalized_duplicate_groups": len(normalized),
        "protected_surfaces": len(protected),
        "authority_surfaces": len(authority),
        "proof_surfaces": len(proof),
        "inventory_files": len(inventory)
    },
    "canonical_owner_proposals": len(owners),
    "unresolved_groups": len(unresolved),
    "alias_proposals": len(aliases),
    "protected_owner_proposals": len(protected_owner_proposals),
    "protected_aliases": len(protected_aliases)
}

(out / "CANONICAL_OWNER_PROPOSALS.json").write_text(
    json.dumps(owners, indent=2)
)
(out / "UNRESOLVED_GROUPS.json").write_text(
    json.dumps(unresolved, indent=2)
)
(out / "REVERSIBLE_ALIAS_MAP.json").write_text(
    json.dumps(aliases, indent=2)
)
(out / "PROTECTED_OWNER_PROPOSALS.json").write_text(
    json.dumps(protected_owner_proposals, indent=2)
)
(out / "PROTECTED_ALIAS_REVIEW.json").write_text(
    json.dumps(protected_aliases, indent=2)
)
(out / "PHASE6_FINAL.json").write_text(
    json.dumps(result, indent=2)
)

print("=== UL7RAVERSE PHASE 6 REAL ===")
print("PHASE6=COMPLETE")
print("MODE=EVIDENCE_BACKED_LOW_RESOURCE")
print("DECISION=REVIEW_REQUIRED")
print("CANONICALITY=PARTIALLY_RESOLVED")
print("AUTHORITY_BOUNDARY=UL7RABRIDGE")
print(f"CANONICAL_OWNER_PROPOSALS={len(owners)}")
print(f"UNRESOLVED_GROUPS={len(unresolved)}")
print(f"ALIAS_PROPOSALS={len(aliases)}")
print(f"PROTECTED_OWNER_PROPOSALS={len(protected_owner_proposals)}")
print(f"PROTECTED_ALIASES={len(protected_aliases)}")
print("SOURCE_MODIFICATION=NONE")
print("PRODUCTION_MODIFICATION=NONE")
print("REAL_UL7RABRIDGE_MODIFICATION=NONE")
print("PRODUCTION_UNLOCK=BLOCKED")
print(f"OUTPUT={out}")
