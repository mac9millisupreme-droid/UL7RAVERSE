import json
import sys
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path.home() / "UL7RAVERSE"
BASE = ROOT / "verification_artifacts" / "forensic_phase5"

runs = sorted([p for p in BASE.iterdir() if p.is_dir()]) if BASE.exists() else []
if not runs:
    print("ERROR=NO_PHASE5_EVIDENCE")
    sys.exit(1)

src = runs[-1]
out = ROOT / "verification_artifacts" / "forensic_phase6_lite" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
out.mkdir(parents=True, exist_ok=True)

def load(name):
    p = src / name
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text(errors="ignore"))
    except Exception:
        return {}

files = {}
for name in [
    "EXACT_DUPLICATES.json",
    "DUPLICATE_GROUPS.json",
    "CANONICALITY_RESOLUTION.json",
    "AUTHORITY_SURFACES.json",
    "PROOF_SURFACES.json",
]:
    files[name] = load(name)

# Discover duplicate-group structures without assuming one exact schema.
groups = []
for obj in files.values():
    if isinstance(obj, dict):
        for key in ("groups", "duplicate_groups", "exact_duplicate_groups", "confirmed_duplicate_groups"):
            val = obj.get(key)
            if isinstance(val, list):
                groups.extend(val)

# Deduplicate serialized groups.
seen = set()
unique = []
for g in groups:
    try:
        k = json.dumps(g, sort_keys=True, default=str)
    except Exception:
        k = repr(g)
    if k not in seen:
        seen.add(k)
        unique.append(g)

# Conservative policy:
# identical-content groups can receive reversible owner proposals;
# anything involving authority/proof remains protected and unresolved.
owners = []
unresolved = []
aliases = []
protected = []
protected_aliases = []

for g in unique:
    if not isinstance(g, dict):
        unresolved.append(g)
        continue

    paths = g.get("paths") or g.get("files") or g.get("members") or []
    if not isinstance(paths, list):
        paths = []

    if len(paths) < 2:
        unresolved.append(g)
        continue

    norm = [str(x) for x in paths]
    ranked = sorted(norm, key=lambda x: (
        "verification_artifacts" in x,
        "/tests/" in x or "/test/" in x,
        "legacy" in x.lower(),
        "experimental" in x.lower(),
        len(x),
        x
    ))

    owner = ranked[0]
    aliases_for_group = [x for x in ranked[1:]]

    protected_flag = any(
        any(term in x.lower() for term in (
            "authority", "bridge", "proof", "security",
            "halo9", "ul7raproof", "cheetah"
        ))
        for x in norm
    )

    record = {
        "owner": owner,
        "aliases": aliases_for_group,
        "members": ranked,
        "basis": "EXACT_DUPLICATE_GROUP_STRUCTURAL_RANKING",
        "reversible": True,
        "destructive_action": False,
    }

    if protected_flag:
        protected.append(record)
        protected_aliases.extend(aliases_for_group)
    else:
        owners.append(record)
        aliases.extend(aliases_for_group)

result = {
    "phase": 6,
    "mode": "LOW_RESOURCE",
    "source_evidence": str(src),
    "decision": "REVIEW_REQUIRED",
    "canonicality": "PARTIALLY_RESOLVED",
    "authority_boundary": "UL7RABRIDGE",
    "source_modification": "NONE",
    "production_modification": "NONE",
    "real_ul7rabridge_modification": "NONE",
    "production_unlock": "BLOCKED",
    "canonical_owner_proposals": owners,
    "unresolved_groups": unresolved,
    "alias_proposals": aliases,
    "protected_owner_proposals": protected,
    "protected_aliases": protected_aliases,
}

(out / "CANONICAL_OWNER_PROPOSALS.json").write_text(json.dumps(owners, indent=2))
(out / "UNRESOLVED_GROUPS.json").write_text(json.dumps(unresolved, indent=2))
(out / "REVERSIBLE_ALIAS_MAP.json").write_text(json.dumps(aliases, indent=2))
(out / "PROTECTED_OWNER_PROPOSALS.json").write_text(json.dumps(protected, indent=2))
(out / "PROTECTED_ALIAS_REVIEW.json").write_text(json.dumps(protected_aliases, indent=2))
(out / "PHASE6_FINAL.json").write_text(json.dumps(result, indent=2))

print("=== UL7RAVERSE PHASE 6 LITE ===")
print("PHASE6=COMPLETE")
print("MODE=LOW_RESOURCE")
print("DECISION=REVIEW_REQUIRED")
print("CANONICALITY=PARTIALLY_RESOLVED")
print("AUTHORITY_BOUNDARY=UL7RABRIDGE")
print(f"CANONICAL_OWNER_PROPOSALS={len(owners)}")
print(f"UNRESOLVED_GROUPS={len(unresolved)}")
print(f"ALIAS_PROPOSALS={len(aliases)}")
print(f"PROTECTED_OWNER_PROPOSALS={len(protected)}")
print(f"PROTECTED_ALIASES={len(protected_aliases)}")
print("SOURCE_MODIFICATION=NONE")
print("PRODUCTION_MODIFICATION=NONE")
print("REAL_UL7RABRIDGE_MODIFICATION=NONE")
print("PRODUCTION_UNLOCK=BLOCKED")
print(f"OUTPUT={out}")
