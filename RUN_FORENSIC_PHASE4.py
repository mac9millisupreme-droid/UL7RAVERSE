#!/usr/bin/env python3
import sys
import json
import hashlib
from pathlib import Path
from datetime import datetime, timezone
from collections import defaultdict

ROOT = Path.home() / "UL7RAVERSE"
PHASE3_ROOT = ROOT / "verification_artifacts" / "forensic_phase3"
PHASE2_ROOT = ROOT / "verification_artifacts" / "forensic_phase2"

def latest_dir(root):
    dirs = [p for p in root.iterdir() if p.is_dir()]
    if not dirs:
        raise RuntimeError(f"No evidence directories found: {root}")
    return sorted(dirs)[-1]

def load_json(path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)

def sha256_file(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def main():
    p3 = latest_dir(PHASE3_ROOT)
    p2 = latest_dir(PHASE2_ROOT)

    out = ROOT / "verification_artifacts" / "forensic_phase4" / \
        datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out.mkdir(parents=True, exist_ok=True)

    artifacts = {
        "phase3": str(p3),
        "phase2": str(p2),
        "phase3_plan": p3 / "PHASE3_EXECUTION_PLAN.json",
        "duplicates": p3 / "DUPLICATE_CANDIDATES.json",
        "authority": p3 / "AUTHORITY_REVIEW.json",
        "proof": p3 / "PROOF_REVIEW.json",
        "critical": p3 / "CRITICAL_COMPONENTS.json",
        "execution": p3 / "EXECUTION_PHASES.json",
        "phase2_plan": p2 / "CONSOLIDATION_PLAN.md",
    }

    missing = [
        str(k) for k, v in artifacts.items()
        if isinstance(v, Path) and not v.exists()
    ]

    if missing:
        raise RuntimeError(
            "Required Phase 2/3 evidence missing: " + ", ".join(missing)
        )

    duplicates = load_json(artifacts["duplicates"])
    authority = load_json(artifacts["authority"])
    proof = load_json(artifacts["proof"])
    critical = load_json(artifacts["critical"])
    execution = load_json(artifacts["execution"])

    def count(x):
        if isinstance(x, list):
            return len(x)
        if isinstance(x, dict):
            return len(x)
        return 0

    duplicate_count = count(duplicates)
    authority_count = count(authority)
    proof_count = count(proof)
    critical_count = count(critical)
    execution_count = count(execution)

    # No automatic destructive decisions.
    # Every candidate begins as REVIEW_REQUIRED unless evidence
    # explicitly establishes a safer classification.
    resolution = {
        "schema": "UL7RAVERSE_FORENSIC_PHASE4/v1",
        "status": "REVIEW_REQUIRED",
        "decision": "CANONICALITY_NOT_YET_PROVEN",
        "rules": {
            "destructive_operations": False,
            "automatic_deletion": False,
            "automatic_merge": False,
            "automatic_overwrite": False,
            "authority_transfer": False,
            "production_modification": False,
            "real_bridge_modification": False,
            "proof_to_authority": False,
            "unknown_to_pass": False,
            "self_certification": False,
        },
        "classification_order": [
            "CANONICAL_CONFIRMED",
            "ALIAS_CONFIRMED",
            "DUPLICATE_CONFIRMED",
            "LEGACY_CONFIRMED",
            "EXPERIMENTAL_CONFIRMED",
            "EVIDENCE_ONLY_CONFIRMED",
            "REVIEW_REQUIRED",
        ],
        "candidate_counts": {
            "duplicate_candidates": duplicate_count,
            "authority_review_items": authority_count,
            "proof_review_items": proof_count,
            "critical_components": critical_count,
            "execution_phases": execution_count,
        },
    }

    # Hash all Phase 3 JSON evidence so the Phase 4 decision can be
    # reproduced against the exact forensic snapshot.
    evidence_hashes = {}
    for name, path in artifacts.items():
        if isinstance(path, Path) and path.is_file():
            evidence_hashes[name] = {
                "path": str(path),
                "sha256": sha256_file(path),
                "size": path.stat().st_size,
            }

    graph = {
        "schema": "UL7RAVERSE_CANONICALITY_GRAPH/v1",
        "authority_boundary": "UL7RABRIDGE",
        "authority_rules": [
            "UL7RABRIDGE_REMAINS_FINAL_AUTHORITY_BOUNDARY",
            "HALO9_NOT_SOVEREIGN_AUTHORITY",
            "LUCI_NOT_AUTHORITY",
            "PROOF_NOT_AUTHORITY",
            "COMMERCE_NOT_AUTHORITY",
            "CLOUD_NOT_SOVEREIGN_AUTHORITY",
        ],
        "proof_rules": [
            "UNVERIFIED_NEVER_PASS",
            "UNKNOWN_REMAINS_UNKNOWN",
            "NO_SELF_CERTIFICATION",
            "FAIL_CLOSED",
        ],
        "edges": [],
        "unresolved": {
            "duplicate_resolution": duplicate_count,
            "authority_resolution": authority_count,
            "proof_resolution": proof_count,
        },
    }

    consolidation = {
        "schema": "UL7RAVERSE_REVERSIBLE_CONSOLIDATION_PLAN/v1",
        "status": "PLANNED_ONLY",
        "production_unlock": "BLOCKED",
        "stages": [
            {
                "stage": 1,
                "name": "Evidence Freeze",
                "action": "HASH_AND_FREEZE_FORENSIC_SNAPSHOTS",
                "destructive": False,
            },
            {
                "stage": 2,
                "name": "Canonical Resolution",
                "action": "RESOLVE_COMPONENT_IDENTITY",
                "destructive": False,
            },
            {
                "stage": 3,
                "name": "Alias Mapping",
                "action": "MAP_CONFIRMED_ALIASES",
                "destructive": False,
            },
            {
                "stage": 4,
                "name": "Duplicate Mapping",
                "action": "MAP_DUPLICATES_WITHOUT_DELETION",
                "destructive": False,
            },
            {
                "stage": 5,
                "name": "Legacy Isolation",
                "action": "ISOLATE_CONFIRMED_LEGACY_SURFACES",
                "destructive": False,
            },
            {
                "stage": 6,
                "name": "Regression Verification",
                "action": "RUN_TESTS_LUCI_PROOF_PURPLE_GOVERNANCE",
                "destructive": False,
            },
            {
                "stage": 7,
                "name": "Human/Governance Review",
                "action": "REVIEW_BEFORE_ANY_REAL_MERGE",
                "destructive": False,
            },
        ],
    }

    final = {
        "schema": "UL7RAVERSE_FORENSIC_PHASE4/v1",
        "phase": 4,
        "phase3_source": str(p3),
        "phase2_source": str(p2),
        "decision": "REVIEW_REQUIRED",
        "canonicality": "NOT_PROVEN",
        "authority_boundary": "UL7RABRIDGE",
        "production_unlock": "BLOCKED",
        "source_modification": "NONE",
        "production_modification": "NONE",
        "real_ul7rabridge_modification": "NONE",
        "candidate_counts": resolution["candidate_counts"],
        "next_phase": "EVIDENCE-BACKED CANONICAL COMPONENT RESOLUTION",
    }

    (out / "CANONICALITY_RESOLUTION.json").write_text(
        json.dumps(resolution, indent=2), encoding="utf-8"
    )
    (out / "CANONICALITY_GRAPH.json").write_text(
        json.dumps(graph, indent=2), encoding="utf-8"
    )
    (out / "REVERSIBLE_CONSOLIDATION_PLAN.json").write_text(
        json.dumps(consolidation, indent=2), encoding="utf-8"
    )
    (out / "FORENSIC_EVIDENCE_HASHES.json").write_text(
        json.dumps(evidence_hashes, indent=2), encoding="utf-8"
    )
    (out / "PHASE4_FINAL.json").write_text(
        json.dumps(final, indent=2), encoding="utf-8"
    )

    report = f"""# UL7RAVERSE FORENSIC PHASE 4

## Decision

REVIEW_REQUIRED

## Canonicality

NOT_PROVEN

## Authority

UL7RABRIDGE remains the final authority boundary.

## Evidence

- Duplicate candidates: {duplicate_count}
- Authority review items: {authority_count}
- Proof review items: {proof_count}
- Critical components: {critical_count}
- Execution phases: {execution_count}

## Safety

- Source modification: NONE
- Production modification: NONE
- Real UL7RABRIDGE modification: NONE
- Automatic deletion: DISABLED
- Automatic merge: DISABLED
- Authority transfer: DISABLED
- Production unlock: BLOCKED

## Governance

UNVERIFIED_NEVER_PASS=ENFORCED
UNKNOWN_REMAINS_UNKNOWN=ENFORCED
PROOF_NOT_AUTHORITY=ENFORCED
LUCI_NOT_AUTHORITY=ENFORCED
HALO9_NOT_SOVEREIGN_AUTHORITY=ENFORCED
FAIL_CLOSED=ENFORCED
NO_SELF_CERTIFICATION=ENFORCED

## Next Phase

EVIDENCE-BACKED CANONICAL COMPONENT RESOLUTION
"""

    (out / "PHASE4_REPORT.md").write_text(report, encoding="utf-8")

    print("=== UL7RAVERSE PHASE 4 ===")
    print("PHASE4=COMPLETE")
    print("DECISION=REVIEW_REQUIRED")
    print("CANONICALITY=NOT_PROVEN")
    print("AUTHORITY_BOUNDARY=UL7RABRIDGE")
    print("SOURCE_MODIFICATION=NONE")
    print("PRODUCTION_MODIFICATION=NONE")
    print("REAL_UL7RABRIDGE_MODIFICATION=NONE")
    print("PRODUCTION_UNLOCK=BLOCKED")
    print(f"DUPLICATE_CANDIDATES={duplicate_count}")
    print(f"AUTHORITY_REVIEW_ITEMS={authority_count}")
    print(f"PROOF_REVIEW_ITEMS={proof_count}")
    print(f"OUTPUT={out}")
    print(f"REPORT={out / 'PHASE4_REPORT.md'}")

if __name__ == "__main__":
    sys.exit(main())
