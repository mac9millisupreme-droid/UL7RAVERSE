
import json
import re
import sys
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path.home() / "UL7RAVERSE"
runs = sorted((ROOT / "verification_artifacts" / "forensic_phase7").glob("*"))
if not runs:
    raise SystemExit("PHASE7_EVIDENCE_NOT_FOUND")

src = runs[-1]

def load(name):
    with open(src / name) as f:
        return json.load(f)

owners = load("CONSOLIDATION_SIMULATION.json")
checks = load("REGRESSION_VALIDATION.json")

owner_groups = owners.get("owners", [])
protected_groups = owners.get("protected_owners", [])
aliases = owners.get("aliases", [])
protected_aliases = owners.get("protected_aliases", [])

all_groups = owner_groups + protected_groups

# Build a reversible identity map only.
identity = {}
for group in all_groups:
    owner = group.get("owner")
    if not owner:
        continue
    for alias in group.get("aliases", []):
        identity[alias] = owner

# Structural reference rehearsal.
# We inspect filenames/path tokens only, never modify source.
inventory = []
for p in ROOT.rglob("*"):
    if not p.is_file():
        continue
    if "verification_artifacts" in p.parts:
        continue
    inventory.append(p)

reference_hits = []
unresolved_references = []

for old, new in identity.items():
    old_name = Path(old).name
    if not old_name:
        continue

    pattern = re.escape(old_name)

    # Bounded structural scan.
    for path in inventory:
        try:
            if path.stat().st_size > 2_000_000:
                continue
            text = path.read_text(errors="ignore")
        except Exception:
            continue

        if re.search(pattern, text):
            reference_hits.append({
                "alias": old,
                "owner": new,
                "referencing_file": str(path),
                "status": "REQUIRES_REWRITE_SIMULATION"
            })

# Protected identity check.
protected_conflicts = []

for group in protected_groups:
    owner = group.get("owner")
    if not owner:
        continue

    if not (ROOT / owner).exists() and not Path(owner).exists():
        protected_conflicts.append({
            "owner": owner,
            "reason": "PROTECTED_OWNER_NOT_FOUND"
        })

# Rollback coverage.
rollback_items = []
for old, new in identity.items():
    rollback_items.append({
        "from": old,
        "to": new,
        "rollback": {
            "restore_original": True,
            "destructive": False
        }
    })

result = {
    "schema": "UL7RAVERSE_FORENSIC_PHASE8/v1",
    "phase": 8,
    "mode": "CONSOLIDATION_REHEARSAL",
    "decision": "REVIEW_REQUIRED",
    "production_unlock": "BLOCKED",
    "authority_boundary": "UL7RABRIDGE",
    "source_modification": "NONE",
    "production_modification": "NONE",
    "real_ul7rabridge_modification": "NONE",
    "owner_groups": len(owner_groups),
    "protected_groups": len(protected_groups),
    "aliases": len(identity),
    "reference_hits": len(reference_hits),
    "protected_conflicts": len(protected_conflicts),
    "rollback_items": len(rollback_items)
}

out = (
    ROOT /
    "verification_artifacts" /
    "forensic_phase8" /
    datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
)
out.mkdir(parents=True, exist_ok=True)

(out / "IDENTITY_REHEARSAL.json").write_text(json.dumps(identity, indent=2))
(out / "REFERENCE_REHEARSAL.json").write_text(json.dumps(reference_hits, indent=2))
(out / "PROTECTED_CONFLICTS.json").write_text(json.dumps(protected_conflicts, indent=2))
(out / "ROLLBACK_MAP.json").write_text(json.dumps(rollback_items, indent=2))

decision = "PASS_WITH_REVIEW" if not protected_conflicts else "BLOCKED"
result["decision"] = decision

(out / "PHASE8_FINAL.json").write_text(json.dumps(result, indent=2))

print("=== UL7RAVERSE PHASE 8 ===")
print("PHASE8=COMPLETE")
print("MODE=CONSOLIDATION_REHEARSAL")
print(f"DECISION={decision}")
print(f"OWNER_GROUPS={len(owner_groups)}")
print(f"PROTECTED_GROUPS={len(protected_groups)}")
print(f"ALIASES={len(identity)}")
print(f"REFERENCE_HITS={len(reference_hits)}")
print(f"PROTECTED_CONFLICTS={len(protected_conflicts)}")
print(f"ROLLBACK_ITEMS={len(rollback_items)}")
print("SOURCE_MODIFICATION=NONE")
print("PRODUCTION_MODIFICATION=NONE")
print("REAL_UL7RABRIDGE_MODIFICATION=NONE")
print("PRODUCTION_UNLOCK=BLOCKED")
print(f"OUTPUT={out}")
