#!/usr/bin/env python3
import sys
import json
import hashlib
import re
from pathlib import Path
from datetime import datetime, timezone
from collections import defaultdict

ROOT = Path.home() / "UL7RAVERSE"
P5ROOT = ROOT / "verification_artifacts" / "forensic_phase5"

SKIP = {
    ".git", "target", "node_modules", "__pycache__",
    ".venv", "venv", ".mypy_cache", ".pytest_cache"
}

TEXT_EXT = {
    ".rs", ".py", ".js", ".ts", ".tsx", ".jsx",
    ".json", ".toml", ".yaml", ".yml", ".md",
    ".sh", ".txt", ".lock", ".cfg", ".ini"
}

AUTHORITY_TERMS = (
    "ul7rabridge", "authority", "authorize", "governance",
    "cheetah", "sovereign", "capability"
)

PROOF_TERMS = (
    "ul7raproof", "proof", "verify", "verification",
    "ledger", "merkle", "replay", "nonce", "revocation"
)

CANONICAL_TERMS = (
    "canonical", "production", "src", "core", "main",
    "lib", "engine", "service"
)

LEGACY_TERMS = (
    "legacy", "deprecated", "archive", "old", "backup",
    "bak", "obsolete"
)

TEST_TERMS = (
    "test", "tests", "fixture", "mock", "stub", "example"
)

EXPERIMENTAL_TERMS = (
    "experimental", "prototype", "scratch", "tmp",
    "temp", "poc", "playground"
)

def latest_dir(root):
    dirs = [p for p in root.iterdir() if p.is_dir()]
    if not dirs:
        raise RuntimeError(f"No evidence directory: {root}")
    return sorted(dirs)[-1]

def load_json(path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)

def read_text(path):
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""

def rel(path):
    return str(path.relative_to(ROOT))

def score_path(path):
    """
    Evidence-based heuristic only.
    Score is NEVER treated as authority.
    """
    s = path.lower()
    score = 0
    reasons = []

    if "src/" in s or "/src/" in s:
        score += 5
        reasons.append("SOURCE_SURFACE")

    if "/tests/" in s or "/test/" in s or "test_" in s:
        score -= 6
        reasons.append("TEST_SURFACE")

    if any(x in s for x in LEGACY_TERMS):
        score -= 8
        reasons.append("LEGACY_NAMING")

    if any(x in s for x in EXPERIMENTAL_TERMS):
        score -= 7
        reasons.append("EXPERIMENTAL_NAMING")

    if any(x in s for x in CANONICAL_TERMS):
        score += 2
        reasons.append("IMPLEMENTATION_NAMING")

    if any(x in s for x in AUTHORITY_TERMS):
        score += 4
        reasons.append("AUTHORITY_SURFACE")

    if any(x in s for x in PROOF_TERMS):
        score += 2
        reasons.append("PROOF_SURFACE")

    if "verification_artifacts" in s:
        score -= 20
        reasons.append("EVIDENCE_ARTIFACT")

    if "/archive/" in s or "/archives/" in s:
        score -= 15
        reasons.append("ARCHIVE_SURFACE")

    if "/backup/" in s or "/backups/" in s:
        score -= 12
        reasons.append("BACKUP_SURFACE")

    return score, reasons

def main():
    p5 = latest_dir(P5ROOT)

    duplicate_file = p5 / "EXACT_DUPLICATE_GROUPS.json"
    authority_file = p5 / "AUTHORITY_SURFACES.json"
    proof_file = p5 / "PROOF_SURFACES.json"
    inventory_file = p5 / "SOURCE_FILE_INVENTORY.json"

    for p in (
        duplicate_file,
        authority_file,
        proof_file,
        inventory_file,
    ):
        if not p.exists():
            raise RuntimeError(f"Missing Phase 5 evidence: {p}")

    duplicates = load_json(duplicate_file)
    authority = load_json(authority_file)
    proof = load_json(proof_file)
    inventory = load_json(inventory_file)

    authority_paths = {x["path"] for x in authority}
    proof_paths = {x["path"] for x in proof}
    inventory_paths = {x["path"] for x in inventory}

    # Build reverse textual reference index.
    source_files = []
    for p in ROOT.rglob("*"):
        if not p.is_file():
            continue
        if any(part in SKIP for part in p.parts):
            continue
        if p.suffix.lower() not in TEXT_EXT:
            continue
        try:
            source_files.append(p)
        except Exception:
            pass

    contents = {}
    for p in source_files:
        contents[rel(p)] = read_text(p)

    def reference_count(candidate):
        """
        Count references to filename/stem from other source files.
        This is dependency evidence, not authority.
        """
        candidate_path = Path(candidate)
        name = candidate_path.name
        stem = candidate_path.stem

        if len(stem) < 3:
            return 0, []

        refs = []
        patterns = [
            re.escape(name),
            re.escape(stem),
        ]

        pattern = re.compile("|".join(patterns), re.IGNORECASE)

        for other, text in contents.items():
            if other == candidate:
                continue
            if pattern.search(text):
                refs.append(other)

        return len(refs), refs[:50]

    owner_map = []
    unresolved = []
    alias_map = []

    for index, group in enumerate(duplicates, start=1):
        paths = group.get("paths", [])

        candidates = []

        for candidate in paths:
            score, reasons = score_path(candidate)
            ref_count, refs = reference_count(candidate)

            if ref_count:
                score += min(ref_count, 10)
                reasons.append(f"REFERENCED_BY_{ref_count}")

            protected = (
                candidate in authority_paths
                or candidate in proof_paths
            )

            if protected:
                reasons.append("PROTECTED_AUTHORITY_OR_PROOF")

            candidates.append({
                "path": candidate,
                "score": score,
                "reasons": reasons,
                "reference_count": ref_count,
                "references": refs,
                "authority_surface": candidate in authority_paths,
                "proof_surface": candidate in proof_paths,
            })

        candidates.sort(
            key=lambda x: (x["score"], x["reference_count"]),
            reverse=True
        )

        if not candidates:
            continue

        top = candidates[0]
        tied = [
            x for x in candidates
            if x["score"] == top["score"]
        ]

        # Canonical owner can only be proposed if there is
        # evidence separation. A tie remains unresolved.
        if len(tied) == 1:
            decision = "CANONICAL_OWNER_PROPOSED"
            owner = top["path"]

            aliases = [
                x["path"] for x in candidates
                if x["path"] != owner
            ]

            owner_map.append({
                "group": index,
                "sha256": group.get("sha256"),
                "decision": decision,
                "proposed_owner": owner,
                "candidates": candidates,
                "proposed_aliases": aliases,
                "action": "MAP_ONLY_NO_DELETE",
            })

            for alias in aliases:
                alias_map.append({
                    "group": index,
                    "alias": alias,
                    "proposed_owner": owner,
                    "action": "REVERSIBLE_ALIAS_MAPPING_ONLY",
                })
        else:
            decision = "UNRESOLVED_TIE"
            unresolved.append({
                "group": index,
                "sha256": group.get("sha256"),
                "decision": decision,
                "candidates": candidates,
                "action": "HUMAN_GOVERNANCE_REVIEW_REQUIRED",
            })

    # Identify protected proposed owners/aliases.
    protected_owner_proposals = [
        x for x in owner_map
        if (
            x["proposed_owner"] in authority_paths
            or x["proposed_owner"] in proof_paths
        )
    ]

    # Never automatically migrate authority/proof-bearing aliases.
    protected_aliases = []
    for x in alias_map:
        if (
            x["alias"] in authority_paths
            or x["alias"] in proof_paths
            or x["proposed_owner"] in authority_paths
            or x["proposed_owner"] in proof_paths
        ):
            protected_aliases.append({
                **x,
                "action": "PROTECTED_REVIEW_REQUIRED",
            })

    governance = {
        "authority_boundary": "UL7RABRIDGE",
        "canonical_owner_selection": "PROPOSAL_ONLY",
        "authority_transfer": False,
        "proof_to_authority": False,
        "automatic_merge": False,
        "automatic_delete": False,
        "source_modification": False,
        "production_modification": False,
        "real_ul7rabridge_modification": False,
        "production_unlock": "BLOCKED",
        "unverified_never_pass": "ENFORCED",
        "unknown_remains_unknown": "ENFORCED",
        "proof_not_authority": "ENFORCED",
        "luci_not_authority": "ENFORCED",
        "halo9_not_sovereign_authority": "ENFORCED",
        "fail_closed": "ENFORCED",
        "no_self_certification": "ENFORCED",
    }

    final = {
        "schema": "UL7RAVERSE_FORENSIC_PHASE6/v1",
        "phase": 6,
        "decision": "REVIEW_REQUIRED",
        "canonicality": (
            "OWNER_PROPOSALS_GENERATED"
            if owner_map else
            "UNRESOLVED"
        ),
        "authority_boundary": "UL7RABRIDGE",
        "production_unlock": "BLOCKED",
        "source_modification": "NONE",
        "production_modification": "NONE",
        "real_ul7rabridge_modification": "NONE",
        "exact_duplicate_groups": len(duplicates),
        "canonical_owner_proposals": len(owner_map),
        "unresolved_groups": len(unresolved),
        "alias_proposals": len(alias_map),
        "protected_owner_proposals": len(protected_owner_proposals),
        "protected_aliases": len(protected_aliases),
        "next_phase": (
            "REVERSIBLE CONSOLIDATION SIMULATION "
            "AND REGRESSION VALIDATION"
        ),
    }

    report = f"""# UL7RAVERSE FORENSIC PHASE 6

## Decision

REVIEW_REQUIRED

## Purpose

Evidence-backed canonical owner selection for exact duplicate groups.

## Results

Exact duplicate groups: {len(duplicates)}

Canonical owner proposals: {len(owner_map)}

Unresolved groups: {len(unresolved)}

Alias proposals: {len(alias_map)}

Protected owner proposals: {len(protected_owner_proposals)}

Protected aliases: {len(protected_aliases)}

## Critical Interpretation

A proposed owner is NOT yet canonical authority.

A proposed alias is NOT yet migrated.

No file has been deleted.

No file has been merged.

No authority has been transferred.

Authority/proof-bearing surfaces remain protected.

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

REVERSIBLE CONSOLIDATION SIMULATION AND REGRESSION VALIDATION
"""

    (out / "CANONICAL_OWNER_PROPOSALS.json").write_text(
        json.dumps(owner_map, indent=2), encoding="utf-8"
    )

    (out / "UNRESOLVED_GROUPS.json").write_text(
        json.dumps(unresolved, indent=2), encoding="utf-8"
    )

    (out / "REVERSIBLE_ALIAS_MAP.json").write_text(
        json.dumps(alias_map, indent=2), encoding="utf-8"
    )

    (out / "PROTECTED_OWNER_PROPOSALS.json").write_text(
        json.dumps(protected_owner_proposals, indent=2),
        encoding="utf-8"
    )

    (out / "PROTECTED_ALIAS_REVIEW.json").write_text(
        json.dumps(protected_aliases, indent=2),
        encoding="utf-8"
    )

    (out / "GOVERNANCE_RESULT.json").write_text(
        json.dumps(governance, indent=2), encoding="utf-8"
    )

    (out / "PHASE6_FINAL.json").write_text(
        json.dumps(final, indent=2), encoding="utf-8"
    )

    (out / "PHASE6_REPORT.md").write_text(
        report, encoding="utf-8"
    )

    print("=== UL7RAVERSE PHASE 6 ===")
    print("PHASE6=COMPLETE")
    print("DECISION=REVIEW_REQUIRED")
    print(f"CANONICAL_OWNER_PROPOSALS={len(owner_map)}")
    print(f"UNRESOLVED_GROUPS={len(unresolved)}")
    print(f"ALIAS_PROPOSALS={len(alias_map)}")
    print(f"PROTECTED_OWNER_PROPOSALS={len(protected_owner_proposals)}")
    print(f"PROTECTED_ALIASES={len(protected_aliases)}")
    print("AUTHORITY_BOUNDARY=UL7RABRIDGE")
    print("SOURCE_MODIFICATION=NONE")
    print("PRODUCTION_MODIFICATION=NONE")
    print("REAL_UL7RABRIDGE_MODIFICATION=NONE")
    print("PRODUCTION_UNLOCK=BLOCKED")
    print(f"OUTPUT={out}")
    print(f"REPORT={out / 'PHASE6_REPORT.md'}")

if __name__ == "__main__":
    sys.exit(main())
