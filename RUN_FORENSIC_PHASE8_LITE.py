
import json
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path.home() / "UL7RAVERSE"

def latest_dir(name):
    base = ROOT / "verification_artifacts" / name
    dirs = sorted(p for p in base.iterdir() if p.is_dir())
    if not dirs:
        raise RuntimeError(f"Missing evidence directory: {base}")
    return dirs[-1]

p7 = latest_dir("forensic_phase7")

with open(p7 / "CONSOLIDATION_SIMULATION.json") as f:
    sim = json.load(f)

with open(p7 / "REGRESSION_VALIDATION.json") as f:
    reg = json.load(f)

owners = sim.get("owners", [])
protected_owners = sim.get("protected_owners", [])
aliases = sim.get("aliases", [])
protected_aliases = sim.get("protected_aliases", [])

identity = []
rollback = []

for group in owners:
    identity.append({
        "owner": group["owner"],
        "aliases": list(group.get("aliases", [])),
        "sha256": group.get("sha256"),
        "protected": False,
        "evidence": group.get("evidence"),
        "reversible": group.get("reversible", True),
    })
    rollback.append({
        "owner": group["owner"],
        "aliases": list(group.get("aliases", [])),
        "action": "REVERSIBLE_ALIAS_ONLY",
        "protected": False,
    })

for group in protected_owners:
    identity.append({
        "owner": group["owner"],
        "aliases": list(group.get("aliases", [])),
        "sha256": group.get("sha256"),
        "protected": True,
        "evidence": group.get("evidence"),
        "reversible": group.get("reversible", True),
    })
    rollback.append({
        "owner": group["owner"],
        "aliases": list(group.get("aliases", [])),
        "action": "REVERSIBLE_ALIAS_ONLY",
        "protected": True,
    })

owner_count_match = len(owners) == 40 and len(protected_owners) == 86
alias_count_match = len(aliases) == 87 and len(protected_aliases) == 583

malformed = [
    g for g in owners + protected_owners
    if not isinstance(g, dict) or not g.get("owner")
]

regression_failures = 0

if isinstance(reg, list):
    for item in reg:
        if isinstance(item, dict):
            status = str(
                item.get("status") or
                item.get("result") or
                ""
            ).upper()
            if status in {"FAIL", "FAILED", "BLOCKED"}:
                regression_failures += 1

conflicts = []

if not owner_count_match:
    conflicts.append({
        "type": "OWNER_COUNT_MISMATCH",
        "actual": [len(owners), len(protected_owners)],
    })

if not alias_count_match:
    conflicts.append({
        "type": "ALIAS_COUNT_MISMATCH",
        "actual": [len(aliases), len(protected_aliases)],
    })

if malformed:
    conflicts.append({
        "type": "MALFORMED_OWNER_GROUPS",
        "count": len(malformed),
    })

if regression_failures:
    conflicts.append({
        "type": "REGRESSION_FAILURES",
        "count": regression_failures,
    })

decision = "PASS_WITH_REVIEW" if not conflicts else "BLOCKED"

result = {
    "schema": "UL7RAVERSE_FORENSIC_PHASE8_LITE/v2",
    "phase": 8,
    "mode": "EVIDENCE_ONLY_LOW_RESOURCE",
    "decision": decision,
    "authority_boundary": "UL7RABRIDGE",
    "owner_groups": len(owners),
    "protected_groups": len(protected_owners),
    "aliases": len(aliases),
    "protected_aliases": len(protected_aliases),
    "identity_items": len(identity),
    "rollback_items": len(rollback),
    "protected_conflicts": len(conflicts),
    "regression_failures": regression_failures,
    "content_scan": "NONE",
    "repository_file_reads": 0,
    "source_modification": "NONE",
    "production_modification": "NONE",
    "real_ul7rabridge_modification": "NONE",
    "production_unlock": "BLOCKED",
    "destructive": False,
}

out = (
    ROOT /
    "verification_artifacts" /
    "forensic_phase8_lite" /
    datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
)

out.mkdir(parents=True, exist_ok=True)

(out / "IDENTITY_REHEARSAL.json").write_text(json.dumps(identity, indent=2))
(out / "ROLLBACK_MAP.json").write_text(json.dumps(rollback, indent=2))
(out / "PROTECTED_CONFLICTS.json").write_text(json.dumps(conflicts, indent=2))
(out / "PHASE8_FINAL.json").write_text(json.dumps(result, indent=2))

print("=== UL7RAVERSE PHASE 8 LITE ===")
print("PHASE8=COMPLETE")
print("MODE=EVIDENCE_ONLY_LOW_RESOURCE")
print(f"DECISION={decision}")
print(f"OWNER_GROUPS={len(owners)}")
print(f"PROTECTED_GROUPS={len(protected_owners)}")
print(f"ALIASES={len(aliases)}")
print(f"PROTECTED_ALIASES={len(protected_aliases)}")
print(f"IDENTITY_ITEMS={len(identity)}")
print(f"PROTECTED_CONFLICTS={len(conflicts)}")
print(f"REGRESSION_FAILURES={regression_failures}")
print(f"ROLLBACK_ITEMS={len(rollback)}")
print("CONTENT_SCAN=NONE")
print("REPOSITORY_FILE_READS=0")
print("SOURCE_MODIFICATION=NONE")
print("PRODUCTION_MODIFICATION=NONE")
print("REAL_UL7RABRIDGE_MODIFICATION=NONE")
print("PRODUCTION_UNLOCK=BLOCKED")
print(f"OUTPUT={out}")
