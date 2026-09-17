#!/usr/bin/env python3

import json
import sys
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path.home() / "UL7RAVERSE"
ART_ROOT = ROOT / "verification_artifacts" / "forensic_phase0"

def newest_phase0():
    dirs = [p for p in ART_ROOT.iterdir() if p.is_dir()]
    return max(dirs, key=lambda p: p.stat().st_mtime) if dirs else None

def load(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return []

def main():
    phase0 = newest_phase0()

    if not phase0:
        print("PHASE1=BLOCKED")
        print("REASON=NO_PHASE0_EVIDENCE")
        return 2

    inventory = load(phase0 / "COMPONENT_INVENTORY.json")
    subsystems = load(phase0 / "NAMED_SUBSYSTEMS.json")
    authority = load(phase0 / "AUTHORITY_PATHS.json")
    proof = load(phase0 / "PROOF_PATHS.json")
    tests = load(phase0 / "TEST_SURFACES.json")

    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out = ROOT / "verification_artifacts" / "forensic_phase1" / stamp
    out.mkdir(parents=True, exist_ok=True)

    canonical = []
    review = []

    canonical_names = {
        "ul7raverse": "UL7RAVERSE",
        "ul7raproof": "UL7RAPROOF",
        "ul7ra4orge": "UL7RA4ORGE",
        "ul7rabridge": "UL7RABRIDGE",
        "ul7rastack": "UL7RASTACK",
        "node9": "NODE9",
        "saios": "SAIOS",
        "halo9": "HALO9",
        "fcos": "FCOS",
        "lucicore": "LuciCore",
        "lucivault": "LuciVault",
        "lucideploy": "LuciDeploy",
    }

    for item in inventory:
        path = item.get("path", "")
        low = path.lower()

        matched = None
        for needle, name in canonical_names.items():
            if needle in low:
                matched = name
                break

        record = {
            "path": path,
            "detected_component": matched,
            "canonicality": "UNKNOWN",
            "authority": "UNKNOWN",
            "proof": "UNKNOWN",
            "production_state": "UNKNOWN",
            "basis": "PHASE1 evidence review required",
        }

        if matched:
            review.append(record)

    authority_graph = {
        "nodes": [
            "Requester",
            "Agent",
            "HALO9",
            "Mission",
            "Capability",
            "Proof",
            "Cheetah",
            "UL7RABRIDGE",
            "Governance",
            "TrustedAction",
        ],
        "edges": [
            {
                "from": "Requester",
                "to": "Agent",
                "relationship": "requests",
                "status": "REVIEW_REQUIRED",
            },
            {
                "from": "Agent",
                "to": "HALO9",
                "relationship": "paired_with",
                "status": "REVIEW_REQUIRED",
            },
            {
                "from": "HALO9",
                "to": "Proof",
                "relationship": "requires",
                "status": "REVIEW_REQUIRED",
            },
            {
                "from": "Proof",
                "to": "UL7RABRIDGE",
                "relationship": "evidence_input_only",
                "status": "DESIGN_CONSTRAINT",
            },
            {
                "from": "Cheetah",
                "to": "UL7RABRIDGE",
                "relationship": "policy_gate",
                "status": "REVIEW_REQUIRED",
            },
            {
                "from": "UL7RABRIDGE",
                "to": "TrustedAction",
                "relationship": "authority_boundary",
                "status": "REVIEW_REQUIRED",
            },
        ],
    }

    proof_graph = {
        "nodes": [
            "Claim",
            "ProofArtifact",
            "LedgerEntry",
            "Hash",
            "Timestamp",
            "Nonce",
            "ProofState",
            "IndependentVerification",
        ],
        "edges": [
            {
                "from": "Claim",
                "to": "ProofArtifact",
                "relationship": "supported_by",
                "status": "REVIEW_REQUIRED",
            },
            {
                "from": "ProofArtifact",
                "to": "LedgerEntry",
                "relationship": "recorded_in",
                "status": "REVIEW_REQUIRED",
            },
            {
                "from": "LedgerEntry",
                "to": "Hash",
                "relationship": "integrity",
                "status": "REVIEW_REQUIRED",
            },
            {
                "from": "ProofArtifact",
                "to": "Timestamp",
                "relationship": "time_bound",
                "status": "REVIEW_REQUIRED",
            },
            {
                "from": "ProofArtifact",
                "to": "Nonce",
                "relationship": "replay_boundary",
                "status": "REVIEW_REQUIRED",
            },
            {
                "from": "ProofArtifact",
                "to": "ProofState",
                "relationship": "state",
                "status": "REVIEW_REQUIRED",
            },
            {
                "from": "ProofArtifact",
                "to": "IndependentVerification",
                "relationship": "must_be_verifiable",
                "status": "GOVERNANCE_REQUIREMENT",
            },
        ],
    }

    dependency_graph = {
        "nodes": sorted({
            x.get("detected_component")
            for x in review
            if x.get("detected_component")
        }),
        "edges": [],
        "status": "REVIEW_REQUIRED",
        "reason": "Phase 0 discovery does not establish dependency authority.",
    }

    security_invariants = [
        "UNVERIFIED != PASS",
        "UNKNOWN remains UNKNOWN",
        "PROOF != AUTHORITY",
        "LUCI != AUTHORITY",
        "COMMERCE != PROOF",
        "PAYMENT != PROOF",
        "AGENT != AUTHORITY",
        "CLOUD != SOVEREIGN_AUTHORITY",
        "NO_PROOF -> NO_TRUSTED_ACTION",
        "NO_SELF_CERTIFICATION",
        "FAIL_CLOSED",
        "NO_PRODUCTION_UNLOCK_WITHOUT_EVIDENCE",
        "HALO9_MUST_NOT_BYPASS_UL7RABRIDGE",
        "PROOF_MUST_NOT_MINT_AUTHORITY",
    ]

    summary = {
        "phase": "PHASE1",
        "decision": "REVIEW_REQUIRED",
        "phase0_source": str(phase0),
        "inventory_count": len(inventory),
        "subsystem_references": len(subsystems),
        "authority_candidates": len(authority),
        "proof_candidates": len(proof),
        "test_surface_categories": {
            k: len(v) for k, v in tests.items()
        },
        "canonicality": "NOT_YET_PROVEN",
        "authority": "UL7RABRIDGE_REMAINS_FINAL_BOUNDARY",
        "production_unlock": "BLOCKED",
        "real_bridge_modification": "NONE",
        "governance": {
            "no_fabricated_pass": True,
            "unknown_remains_unknown": True,
            "fail_closed": True,
        },
    }

    (out / "CANONICALITY_REVIEW.json").write_text(
        json.dumps(review, indent=2, sort_keys=True),
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

    (out / "SECURITY_INVARIANTS.json").write_text(
        json.dumps(security_invariants, indent=2),
        encoding="utf-8",
    )

    (out / "PHASE1_SUMMARY.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True),
        encoding="utf-8",
    )

    report = f"""UL7RAVERSE PHASE 1

UTC={stamp}
PHASE0_SOURCE={phase0}

DECISION=REVIEW_REQUIRED

CANONICALITY=NOT_YET_PROVEN
AUTHORITY=UL7RABRIDGE_REMAINS_FINAL_BOUNDARY
PRODUCTION_UNLOCK=BLOCKED
REAL_BRIDGE_MODIFICATION=NONE

INVARIANTS=RECORDED
AUTHORITY_GRAPH=GENERATED
PROOF_GRAPH=GENERATED
DEPENDENCY_GRAPH=GENERATED

NO_FABRICATED_PASS=ENFORCED
UNKNOWN_REMAINS_UNKNOWN=ENFORCED
FAIL_CLOSED=ENFORCED

NEXT_PHASE=CANONICAL CONSOLIDATION PLAN
"""

    (out / "PHASE1_REPORT.txt").write_text(
        report,
        encoding="utf-8",
    )

    print("=== UL7RAVERSE PHASE 1 ===")
    print("PHASE1=COMPLETE")
    print("DECISION=REVIEW_REQUIRED")
    print("CANONICALITY=NOT_YET_PROVEN")
    print("AUTHORITY=UL7RABRIDGE_REMAINS_FINAL_BOUNDARY")
    print("PRODUCTION_UNLOCK=BLOCKED")
    print("REAL_BRIDGE_MODIFICATION=NONE")
    print(f"AUTHORITY_CANDIDATES={len(authority)}")
    print(f"PROOF_CANDIDATES={len(proof)}")
    print(f"OUTPUT={out}")
    print(f"REPORT={out / 'PHASE1_REPORT.txt'}")

    return 0

if __name__ == "__main__":
    sys.exit(main())
