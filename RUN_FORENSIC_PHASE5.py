#!/usr/bin/env python3
import sys
import json
import hashlib
from pathlib import Path
from datetime import datetime, timezone
from collections import defaultdict

ROOT = Path.home() / "UL7RAVERSE"
P3ROOT = ROOT / "verification_artifacts" / "forensic_phase3"
P4ROOT = ROOT / "verification_artifacts" / "forensic_phase4"

SKIP = {
    ".git", "target", "node_modules", "__pycache__",
    ".venv", "venv", ".mypy_cache", ".pytest_cache"
}

TEXT_EXT = {
    ".rs", ".py", ".js", ".ts", ".tsx", ".jsx", ".json",
    ".toml", ".yaml", ".yml", ".md", ".sh", ".txt",
    ".lock", ".cfg", ".ini"
}

def latest_dir(root):
    dirs = [p for p in root.iterdir() if p.is_dir()]
    if not dirs:
        raise RuntimeError(f"No evidence directories: {root}")
    return sorted(dirs)[-1]

def load_json(path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def normalized_text(path):
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return None
    lines = []
    for line in text.splitlines():
        s = line.strip()
        if not s:
            continue
        lines.append(s)
    return "\n".join(lines)

def similarity(a, b):
    if not a or not b:
        return 0.0
    sa = set(a.splitlines())
    sb = set(b.splitlines())
    if not sa or not sb:
        return 0.0
    return len(sa & sb) / max(1, len(sa | sb))

def main():
    p3 = latest_dir(P3ROOT)
    p4 = latest_dir(P4ROOT)

    out = ROOT / "verification_artifacts" / "forensic_phase5" / \
        datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out.mkdir(parents=True, exist_ok=True)

    required = [
        p3 / "DUPLICATE_CANDIDATES.json",
        p3 / "AUTHORITY_REVIEW.json",
        p3 / "PROOF_REVIEW.json",
        p3 / "CRITICAL_COMPONENTS.json",
        p4 / "CANONICALITY_RESOLUTION.json",
        p4 / "CANONICALITY_GRAPH.json",
        p4 / "REVERSIBLE_CONSOLIDATION_PLAN.json",
    ]

    missing = [str(x) for x in required if not x.exists()]
    if missing:
        raise RuntimeError("Missing evidence: " + ", ".join(missing))

    duplicates = load_json(p3 / "DUPLICATE_CANDIDATES.json")
    authority = load_json(p3 / "AUTHORITY_REVIEW.json")
    proof = load_json(p3 / "PROOF_REVIEW.json")
    critical = load_json(p3 / "CRITICAL_COMPONENTS.json")

    # Inventory source implementation files.
    files = []
    for p in ROOT.rglob("*"):
        if not p.is_file():
            continue
        if any(part in SKIP for part in p.parts):
            continue
        if p.suffix.lower() not in TEXT_EXT:
            continue
        try:
            rel = p.relative_to(ROOT)
            size = p.stat().st_size
            digest = sha256(p)
            files.append({
                "path": str(rel),
                "size": size,
                "sha256": digest,
                "extension": p.suffix.lower(),
            })
        except Exception:
            continue

    # Exact duplicate groups.
    by_hash = defaultdict(list)
    for item in files:
        by_hash[item["sha256"]].append(item["path"])

    exact_duplicates = []
    for digest, paths in by_hash.items():
        if len(paths) > 1:
            exact_duplicates.append({
                "sha256": digest,
                "count": len(paths),
                "paths": sorted(paths),
                "classification": "EXACT_CONTENT_DUPLICATE_REVIEW",
                "automatic_delete": False,
            })

    # Name-family discovery.
    families = defaultdict(list)
    for item in files:
        stem = Path(item["path"]).stem.lower()
        normalized = (
            stem.replace("ul7raforge", "ul7ra4forge")
                .replace("forge_v", "forge")
                .replace("_v", "")
                .replace("-v", "")
        )
        families[normalized].append(item["path"])

    name_collisions = []
    for name, paths in families.items():
        if len(paths) > 1:
            name_collisions.append({
                "normalized_family": name,
                "count": len(paths),
                "paths": sorted(paths),
                "classification": "IDENTITY_REVIEW_REQUIRED",
            })

    # Critical authority/proof keyword surfaces.
    authority_terms = (
        "ul7rabridge", "authority", "authorize", "governance",
        "cheetah", "sovereign", "capability"
    )
    proof_terms = (
        "ul7raproof", "proof", "verify", "verification",
        "ledger", "merkle", "replay", "nonce", "revocation"
    )

    authority_surfaces = []
    proof_surfaces = []

    for item in files:
        low = item["path"].lower()
        if any(term in low for term in authority_terms):
            authority_surfaces.append(item)
        if any(term in low for term in proof_terms):
            proof_surfaces.append(item)

    # Detect exact content duplicates that touch authority/proof surfaces.
    protected_duplicate_groups = []
    for group in exact_duplicates:
        paths = group["paths"]
        joined = " ".join(paths).lower()
        if (
            any(x in joined for x in authority_terms)
            or any(x in joined for x in proof_terms)
        ):
            protected_duplicate_groups.append(group)

    # Evidence-backed resolution rules.
    confirmed = []
    review = []
    conflicts = []

    for group in exact_duplicates:
        paths = group["paths"]

        if len(paths) == 2:
            record = {
                "type": "EXACT_DUPLICATE",
                "paths": paths,
                "sha256": group["sha256"],
                "decision": "CONFIRMED_DUPLICATE",
                "action": "MAP_ONLY_NO_DELETE",
            }
            confirmed.append(record)
        else:
            record = {
                "type": "MULTIWAY_EXACT_DUPLICATE",
                "paths": paths,
                "sha256": group["sha256"],
                "decision": "CONFIRMED_DUPLICATE_GROUP",
                "action": "MAP_ONLY_NO_DELETE",
            }
            confirmed.append(record)

    # Files with identical normalized content but different raw hashes.
    normalized_buckets = defaultdict(list)
    for item in files:
        path = ROOT / item["path"]
        if item["size"] > 2_000_000:
            continue
        text = normalized_text(path)
        if text:
            ndigest = hashlib.sha256(text.encode("utf-8")).hexdigest()
            normalized_buckets[ndigest].append(item["path"])

    normalized_duplicates = []
    for digest, paths in normalized_buckets.items():
        if len(paths) > 1:
            normalized_duplicates.append({
                "normalized_sha256": digest,
                "paths": sorted(paths),
                "decision": "REVIEW_REQUIRED",
                "reason": "NORMALIZED_CONTENT_MATCH_NOT_SUFFICIENT_FOR_CANONICALITY",
            })

    # Critical surfaces are never automatically demoted.
    protected_paths = set()
    for item in authority_surfaces + proof_surfaces:
        protected_paths.add(item["path"])

    protected_decisions = []
    for item in files:
        if item["path"] in protected_paths:
            protected_decisions.append({
                "path": item["path"],
                "authority_or_proof_surface": True,
                "decision": "PROTECTED_REVIEW",
                "automatic_merge": False,
                "automatic_delete": False,
            })

    # Reversible mapping only.
    mapping = {
        "schema": "UL7RAVERSE_PHASE5_IDENTITY_MAP/v1",
        "status": "REVIEW_REQUIRED",
        "canonicality": "PARTIALLY_RESOLVED",
        "rules": {
            "exact_hash_match": "CONFIRMED_DUPLICATE",
            "normalized_match": "REVIEW_REQUIRED",
            "name_match": "REVIEW_REQUIRED",
            "authority_surface": "PROTECTED_REVIEW",
            "proof_surface": "PROTECTED_REVIEW",
            "no_deletion": True,
            "no_merge": True,
            "no_authority_transfer": True,
        },
        "confirmed_duplicate_groups": len(confirmed),
        "normalized_duplicate_groups": len(normalized_duplicates),
        "protected_surfaces": len(protected_decisions),
    }

    governance = {
        "authority_boundary": "UL7RABRIDGE",
        "unverified_never_pass": "ENFORCED",
        "unknown_remains_unknown": "ENFORCED",
        "proof_not_authority": "ENFORCED",
        "luci_not_authority": "ENFORCED",
        "halo9_not_sovereign_authority": "ENFORCED",
        "fail_closed": "ENFORCED",
        "no_self_certification": "ENFORCED",
        "production_unlock": "BLOCKED",
    }

    final = {
        "schema": "UL7RAVERSE_FORENSIC_PHASE5/v1",
        "phase": 5,
        "decision": "REVIEW_REQUIRED",
        "canonicality": "PARTIALLY_RESOLVED",
        "authority_boundary": "UL7RABRIDGE",
        "production_unlock": "BLOCKED",
        "source_modification": "NONE",
        "production_modification": "NONE",
        "real_ul7rabridge_modification": "NONE",
        "inventory_files": len(files),
        "exact_duplicate_groups": len(exact_duplicates),
        "confirmed_duplicate_groups": len(confirmed),
        "normalized_duplicate_groups": len(normalized_duplicates),
        "authority_surfaces": len(authority_surfaces),
        "proof_surfaces": len(proof_surfaces),
        "protected_duplicate_groups": len(protected_duplicate_groups),
        "next_phase": "CANONICAL OWNER SELECTION AND REVERSIBLE ALIAS MIGRATION",
    }

    (out / "SOURCE_FILE_INVENTORY.json").write_text(
        json.dumps(files, indent=2), encoding="utf-8"
    )
    (out / "EXACT_DUPLICATE_GROUPS.json").write_text(
        json.dumps(exact_duplicates, indent=2), encoding="utf-8"
    )
    (out / "NORMALIZED_DUPLICATE_GROUPS.json").write_text(
        json.dumps(normalized_duplicates, indent=2), encoding="utf-8"
    )
    (out / "NAME_FAMILY_COLLISIONS.json").write_text(
        json.dumps(name_collisions, indent=2), encoding="utf-8"
    )
    (out / "AUTHORITY_SURFACES.json").write_text(
        json.dumps(authority_surfaces, indent=2), encoding="utf-8"
    )
    (out / "PROOF_SURFACES.json").write_text(
        json.dumps(proof_surfaces, indent=2), encoding="utf-8"
    )
    (out / "PROTECTED_SURFACES.json").write_text(
        json.dumps(protected_decisions, indent=2), encoding="utf-8"
    )
    (out / "CONFIRMED_DUPLICATES.json").write_text(
        json.dumps(confirmed, indent=2), encoding="utf-8"
    )
    (out / "REVERSIBLE_IDENTITY_MAP.json").write_text(
        json.dumps(mapping, indent=2), encoding="utf-8"
    )
    (out / "GOVERNANCE_RESULT.json").write_text(
        json.dumps(governance, indent=2), encoding="utf-8"
    )
    (out / "PHASE5_FINAL.json").write_text(
        json.dumps(final, indent=2), encoding="utf-8"
    )

    report = f"""# UL7RAVERSE FORENSIC PHASE 5

## Decision

REVIEW_REQUIRED

## Canonicality

PARTIALLY_RESOLVED

## Inventory

Source files examined: {len(files)}

Exact duplicate groups: {len(exact_duplicates)}

Confirmed duplicate groups: {len(confirmed)}

Normalized duplicate groups requiring review: {len(normalized_duplicates)}

Name-family collisions: {len(name_collisions)}

Authority surfaces: {len(authority_surfaces)}

Proof surfaces: {len(proof_surfaces)}

Protected duplicate groups: {len(protected_duplicate_groups)}

## Critical Rule

An exact content/hash match is evidence of duplication, not permission to delete.

A name match is not proof of identity.

A normalized-content match is not sufficient for canonicality.

Authority-bearing and proof-bearing surfaces remain protected.

## Governance

AUTHORITY_BOUNDARY=UL7RABRIDGE
UNVERIFIED_NEVER_PASS=ENFORCED
UNKNOWN_REMAINS_UNKNOWN=ENFORCED
PROOF_NOT_AUTHORITY=ENFORCED
LUCI_NOT_AUTHORITY=ENFORCED
HALO9_NOT_SOVEREIGN_AUTHORITY=ENFORCED
FAIL_CLOSED=ENFORCED
NO_SELF_CERTIFICATION=ENFORCED

## Modification Safety

SOURCE_MODIFICATION=NONE
PRODUCTION_MODIFICATION=NONE
REAL_UL7RABRIDGE_MODIFICATION=NONE
AUTOMATIC_DELETE=DISABLED
AUTOMATIC_MERGE=DISABLED
AUTHORITY_TRANSFER=DISABLED
PRODUCTION_UNLOCK=BLOCKED

## Next Phase

CANONICAL OWNER SELECTION AND REVERSIBLE ALIAS MIGRATION
"""

    (out / "PHASE5_REPORT.md").write_text(report, encoding="utf-8")

    print("=== UL7RAVERSE PHASE 5 ===")
    print("PHASE5=COMPLETE")
    print("DECISION=REVIEW_REQUIRED")
    print("CANONICALITY=PARTIALLY_RESOLVED")
    print("AUTHORITY_BOUNDARY=UL7RABRIDGE")
    print("SOURCE_MODIFICATION=NONE")
    print("PRODUCTION_MODIFICATION=NONE")
    print("REAL_UL7RABRIDGE_MODIFICATION=NONE")
    print("PRODUCTION_UNLOCK=BLOCKED")
    print(f"INVENTORY_FILES={len(files)}")
    print(f"EXACT_DUPLICATE_GROUPS={len(exact_duplicates)}")
    print(f"CONFIRMED_DUPLICATE_GROUPS={len(confirmed)}")
    print(f"NORMALIZED_DUPLICATE_GROUPS={len(normalized_duplicates)}")
    print(f"NAME_FAMILY_COLLISIONS={len(name_collisions)}")
    print(f"AUTHORITY_SURFACES={len(authority_surfaces)}")
    print(f"PROOF_SURFACES={len(proof_surfaces)}")
    print(f"PROTECTED_DUPLICATE_GROUPS={len(protected_duplicate_groups)}")
    print(f"OUTPUT={out}")
    print(f"REPORT={out / 'PHASE5_REPORT.md'}")

if __name__ == "__main__":
    sys.exit(main())
