#!/usr/bin/env python3

import json
import sys
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path.home() / "UL7RAVERSE"
BASE = ROOT / "verification_artifacts"

def newest_dir(parent):
    dirs = [p for p in parent.iterdir() if p.is_dir()]
    return max(dirs, key=lambda p: p.stat().st_mtime) if dirs else None

def load(path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default

def main():
    phase1_root = BASE / "forensic_phase1"
    phase1 = newest_dir(phase1_root)

    if not phase1:
        print("PHASE2=BLOCKED")
        print("REASON=NO_PHASE1_ARTIFACTS")
        return 2

    phase0_root = BASE / "forensic_phase0"
    phase0 = newest_dir(phase0_root)

    inventory = load(
        phase0 / "COMPONENT_INVENTORY.json"
        if phase0 else Path("/nonexistent"),
        []
    )

    canonicality = load(
        phase1 / "CANONICALITY_REVIEW.json",
        []
    )

    authority = load(
        phase0 / "AUTHORITY_PATHS.json"
        if phase0 else Path("/nonexistent"),
        []
    )

    proof = load(
        phase0 / "PROOF_PATHS.json"
        if phase0 else Path("/nonexistent"),
        []
    )

    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out = BASE / "forensic_phase2" / stamp
    out.mkdir(parents=True, exist_ok=True)

    categories = {
        "CANONICAL_CANDIDATE": [],
        "DUPLICATE_CANDIDATE": [],
        "LEGACY_CANDIDATE": [],
        "ALIAS_CANDIDATE": [],
        "EXPERIMENTAL_CANDIDATE": [],
        "EVIDENCE_ONLY_CANDIDATE": [],
        "PRODUCTION_CANDIDATE": [],
        "REVIEW_REQUIRED": [],
    }

    canonical_names = [
        "ul7raverse",
        "ul7raproof",
        "ul7ra4orge",
        "ul7rabridge",
        "ul7rastack",
        "node9",
        "saios",
        "halo9",
        "fcos",
        "lucicore",
        "lucivault",
        "lucideploy",
    ]

    for item in inventory:
        path = item.get("path", "")
        low = path.lower()

        record = {
            "path": path,
            "type": item.get("type", ""),
            "classification": "REVIEW_REQUIRED",
            "reason": [],
        }

        if any(x in low for x in [
            "backup",
            "deprecated",
            "legacy",
            "/old/",
            "/archive/",
        ]):
            record["classification"] = "LEGACY_CANDIDATE"
            record["reason"].append(
                "Path naming suggests historical/legacy material."
            )

        elif "verification_artifacts" in low:
            record["classification"] = "EVIDENCE_ONLY_CANDIDATE"
            record["reason"].append(
                "Located beneath verification_artifacts."
            )

        elif "experimental" in low or "prototype" in low:
            record["classification"] = "EXPERIMENTAL_CANDIDATE"
            record["reason"].append(
                "Path naming suggests experimental material."
            )

        elif any(name in low for name in canonical_names):
            record["classification"] = "CANONICAL_CANDIDATE"
            record["reason"].append(
                "Named canonical subsystem candidate."
            )

        else:
            record["classification"] = "REVIEW_REQUIRED"

        categories[record["classification"]].append(record)

    authority_graph = {
        "authority_boundary": "UL7RABRIDGE",
        "authority_minting_allowed_outside_bridge": False,
        "proof_grants_authority": False,
        "luci_grants_authority": False,
        "agent_grants_authority": False,
        "commerce_grants_authority": False,
        "cloud_grants_authority": False,
        "nodes": [
            "Requester",
            "Agent",
            "HALO9",
            "Mission",
            "Capability",
            "Proof",
            "Cheetah",
            "Governance",
            "UL7RABRIDGE",
            "TrustedAction",
        ],
        "required_order": [
            "Requester",
            "Agent",
            "HALO9",
            "Mission",
            "Capability",
            "Proof",
            "Cheetah",
            "Governance",
            "UL7RABRIDGE",
            "TrustedAction",
        ],
        "status": "REVIEW_REQUIRED",
    }

    proof_graph = {
        "proof_is_evidence": True,
        "proof_is_authority": False,
        "claim_must_be_bound_to_evidence": True,
        "ledger_integrity_required": True,
        "replay_protection_required": True,
        "revocation_required_where_applicable": True,
        "expiry_required_where_applicable": True,
        "independent_verification_required": True,
        "candidate_count": len(proof),
        "status": "REVIEW_REQUIRED",
    }

    dependency_graph = {
        "nodes": sorted({
            x.get("path", "")
            for x in inventory
            if x.get("path")
        }),
        "edges": [],
        "status": "REVIEW_REQUIRED",
        "note": (
            "Phase 2 does not invent dependencies. "
            "Only dependencies directly recoverable from evidence "
            "may be promoted into the final graph."
        ),
    }

    consolidation_rules = [
        "Preserve working behavior unless evidence proves replacement is safe.",
        "Do not delete duplicate-looking components during discovery.",
        "UL7RA4ORGE is the canonical forge candidate; UL7RAFORGE requires evidence-based alias classification.",
        "UL7RABRIDGE remains the authority boundary.",
        "HALO9 may gate but must not independently grant sovereign authority.",
        "LUCI may evaluate and diagnose but must not grant authority.",
        "UL7RAPROOF provides evidence but must not mint authority.",
        "Commerce and payment must never become proof of trust.",
        "Cloud infrastructure must never silently become sovereign authority.",
        "Unknown remains unknown.",
        "Unverified never becomes pass.",
        "No production unlock without reproducible evidence.",
        "No fabricated dependency, customer, revenue, proof, or production claim.",
        "Legacy code remains preserved until migration evidence exists.",
        "Every consolidation operation must be reversible.",
    ]

    required_outputs = [
        "ARCHITECTURE_CANONICAL.md",
        "ARCHITECTURE_GRAPH.json",
        "DEPENDENCY_GRAPH.json",
        "AUTHORITY_GRAPH.json",
        "PROOF_GRAPH.json",
        "SECURITY_INVARIANTS.md",
        "COMPONENT_INVENTORY.json",
        "CONSOLIDATION_PLAN.md",
        "CONSOLIDATION_STATUS.md",
        "REGRESSION_MATRIX.md",
        "PRODUCTION_READINESS.md",
        "FINAL_GOVERNANCE_REPORT.md",
    ]

    plan = {
        "phase": "PHASE2_CANONICAL_CONSOLIDATION_PLANNING",
        "decision": "REVIEW_REQUIRED",
        "phase1_source": str(phase1),
        "counts": {
            "inventory": len(inventory),
            "authority_candidates": len(authority),
            "proof_candidates": len(proof),
            "canonical_candidates": len(
                categories["CANONICAL_CANDIDATE"]
            ),
            "legacy_candidates": len(
                categories["LEGACY_CANDIDATE"]
            ),
            "experimental_candidates": len(
                categories["EXPERIMENTAL_CANDIDATE"]
            ),
            "evidence_candidates": len(
                categories["EVIDENCE_ONLY_CANDIDATE"]
            ),
        },
        "classification": categories,
        "authority_model": authority_graph,
        "proof_model": proof_graph,
        "dependency_model": dependency_graph,
        "rules": consolidation_rules,
        "required_outputs": required_outputs,
        "production_unlock": "BLOCKED",
        "real_bridge_modification": "NONE",
    }

    (out / "CONSOLIDATION_PLAN.json").write_text(
        json.dumps(plan, indent=2, sort_keys=True),
        encoding="utf-8",
    )

    (out / "AUTHORITY_GRAPH.json").write_text(
        json.dumps(authority_graph, indent=2, sort_keys=True),
        encoding="utf-8",
    )

    (out / "PROOF_GRAPH.json").write_text(
        json.dumps(proof_graph, indent=2, sort_keys=True),
        encoding="utf-8",
    )

    (out / "DEPENDENCY_GRAPH.json").write_text(
        json.dumps(dependency_graph, indent=2, sort_keys=True),
        encoding="utf-8",
    )

    md = f"""# UL7RAVERSE Canonical Consolidation Plan

## Decision

`REVIEW_REQUIRED`

## Governance

- UNKNOWN remains UNKNOWN.
- UNVERIFIED is never PASS.
- Proof does not grant authority.
- LUCI does not grant authority.
- HALO9 does not independently grant sovereign authority.
- UL7RABRIDGE remains the authority boundary.
- Production unlock remains BLOCKED.

## Discovery Counts

- Inventory: {len(inventory)}
- Authority candidates: {len(authority)}
- Proof candidates: {len(proof)}
- Canonical candidates: {len(categories["CANONICAL_CANDIDATE"])}
- Legacy candidates: {len(categories["LEGACY_CANDIDATE"])}
- Experimental candidates: {len(categories["EXPERIMENTAL_CANDIDATE"])}
- Evidence candidates: {len(categories["EVIDENCE_ONLY_CANDIDATE"])}

## Consolidation Rules

"""

    for rule in consolidation_rules:
        md += f"- {rule}\n"

    md += """
## Required Next Work

1. Resolve canonicality conflicts.
2. Build evidence-backed dependency edges.
3. Validate actual authority paths.
4. Separate proof creation from authority.
5. Identify duplicate implementations.
6. Identify legacy aliases.
7. Build reversible migration plan.
8. Build regression matrix.
9. Run Purple Team analysis.
10. Only then consider source consolidation.

## Production

`PRODUCTION_UNLOCK=BLOCKED`

`REAL_UL7RABRIDGE_MODIFICATION=NONE`
"""

    (out / "CONSOLIDATION_PLAN.md").write_text(
        md,
        encoding="utf-8",
    )

    summary = {
        "phase": 2,
        "decision": "REVIEW_REQUIRED",
        "canonicality": "NOT_PROVEN",
        "authority_boundary": "UL7RABRIDGE",
        "production_unlock": "BLOCKED",
        "real_bridge_modification": "NONE",
        "counts": plan["counts"],
        "next_phase": "EVIDENCE-BACKED CONSOLIDATION EXECUTION PLAN",
    }

    (out / "PHASE2_SUMMARY.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True),
        encoding="utf-8",
    )

    print("=== UL7RAVERSE PHASE 2 ===")
    print("PHASE2=COMPLETE")
    print("DECISION=REVIEW_REQUIRED")
    print("CANONICALITY=NOT_PROVEN")
    print("AUTHORITY=UL7RABRIDGE")
    print("PRODUCTION_UNLOCK=BLOCKED")
    print("REAL_UL7RABRIDGE_MODIFICATION=NONE")
    print(f"INVENTORY={len(inventory)}")
    print(f"AUTHORITY_CANDIDATES={len(authority)}")
    print(f"PROOF_CANDIDATES={len(proof)}")
    print(f"CANONICAL_CANDIDATES={len(categories['CANONICAL_CANDIDATE'])}")
    print(f"LEGACY_CANDIDATES={len(categories['LEGACY_CANDIDATE'])}")
    print(f"EXPERIMENTAL_CANDIDATES={len(categories['EXPERIMENTAL_CANDIDATE'])}")
    print(f"OUTPUT={out}")
    print(f"PLAN={out / 'CONSOLIDATION_PLAN.md'}")

    return 0

if __name__ == "__main__":
    sys.exit(main())
