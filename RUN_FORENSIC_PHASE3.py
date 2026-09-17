import sys
#!/usr/bin/env python3

import json
import hashlib
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path.home() / "UL7RAVERSE"
BASE = ROOT / "verification_artifacts"

def newest(parent):
    if not parent.exists():
        return None
    dirs = [p for p in parent.iterdir() if p.is_dir()]
    return max(dirs, key=lambda p: p.stat().st_mtime) if dirs else None

def load(path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default

def sha(path):
    try:
        h = hashlib.sha256()
        with path.open("rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                h.update(chunk)
        return h.hexdigest()
    except Exception:
        return ""

def text(path):
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""

def main():
    p2root = BASE / "forensic_phase2"
    p2 = newest(p2root)

    if not p2:
        print("PHASE3=BLOCKED")
        print("REASON=NO_PHASE2_ARTIFACTS")
        return 2

    p0 = newest(BASE / "forensic_phase0")
    p1 = newest(BASE / "forensic_phase1")

    inventory = load(
        p0 / "COMPONENT_INVENTORY.json" if p0 else Path("/none"),
        []
    )

    authority = load(
        p0 / "AUTHORITY_PATHS.json" if p0 else Path("/none"),
        []
    )

    proof = load(
        p0 / "PROOF_PATHS.json" if p0 else Path("/none"),
        []
    )

    phase2 = load(
        p2 / "CONSOLIDATION_PLAN.json",
        {}
    )

    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out = BASE / "forensic_phase3" / stamp
    out.mkdir(parents=True, exist_ok=True)

    # ------------------------------------------------------------
    # 1. IDENTIFY REAL IMPLEMENTATION SURFACES
    # ------------------------------------------------------------

    implementation = []

    for item in inventory:
        path = item.get("path", "")
        full = ROOT / path

        if not full.exists():
            continue

        kind = item.get("type", "")

        if kind in {
            "rust_crate_manifest",
            "python_project",
            "javascript_project",
            "shell_script",
            "source_or_other",
            "policy_governance",
            "schema",
            "network_boundary",
            "service_definition",
        }:
            implementation.append({
                "path": path,
                "type": kind,
                "sha256": sha(full),
                "implementation_surface": True,
                "canonicality": "UNRESOLVED",
            })

    # ------------------------------------------------------------
    # 2. BUILD MANIFEST INDEX
    # ------------------------------------------------------------

    manifests = []

    for item in inventory:
        path = item.get("path", "")
        full = ROOT / path

        if not full.exists():
            continue

        if full.name in {
            "Cargo.toml",
            "package.json",
            "pyproject.toml",
            "requirements.txt",
            "setup.py",
        }:
            manifests.append({
                "path": path,
                "type": item.get("type"),
                "sha256": sha(full),
                "content_size": full.stat().st_size,
            })

    # ------------------------------------------------------------
    # 3. FIND EXPLICIT UL7RA / HALO9 / LUCI BOUNDARIES
    # ------------------------------------------------------------

    boundary_terms = [
        "UL7RABRIDGE",
        "UL7RAPROOF",
        "HALO9",
        "LUCITEST",
        "LUCIDIAGNOSTIC",
        "Cheetah",
        "authority",
        "production_unlock",
        "fail_closed",
        "proof",
    ]

    boundaries = []

    for item in inventory:
        path = item.get("path", "")
        full = ROOT / path

        if not full.exists() or full.is_dir():
            continue

        try:
            if full.stat().st_size > 5 * 1024 * 1024:
                continue
        except Exception:
            continue

        content = text(full)

        if not content:
            continue

        hits = [
            term for term in boundary_terms
            if term.lower() in content.lower()
        ]

        if hits:
            boundaries.append({
                "path": path,
                "terms": sorted(set(hits)),
                "sha256": sha(full),
                "status": "REVIEW_REQUIRED",
            })

    # ------------------------------------------------------------
    # 4. IDENTIFY LIKELY DUPLICATE / PARALLEL IMPLEMENTATIONS
    # ------------------------------------------------------------

    basename_groups = {}

    for item in implementation:
        path = Path(item["path"])
        key = path.name.lower()
        basename_groups.setdefault(key, []).append(item["path"])

    duplicate_candidates = []

    for basename, paths in basename_groups.items():
        if len(paths) > 1:
            duplicate_candidates.append({
                "basename": basename,
                "paths": sorted(paths),
                "classification": "DUPLICATE_CANDIDATE",
                "decision": "DO_NOT_MERGE_YET",
            })

    # ------------------------------------------------------------
    # 5. IDENTIFY NAMED FORGE / BRIDGE / HALO9 SURFACES
    # ------------------------------------------------------------

    critical_components = {}

    for name in [
        "UL7RA4ORGE",
        "UL7RAFORGE",
        "UL7RABRIDGE",
        "HALO9",
        "UL7RAPROOF",
        "LUCI",
    ]:
        hits = []

        needle = name.lower()

        for item in inventory:
            path = item.get("path", "")

            if needle in path.lower():
                hits.append(path)

        critical_components[name] = sorted(set(hits))

    # ------------------------------------------------------------
    # 6. AUTHORITY RISK REVIEW
    # ------------------------------------------------------------

    authority_review = []

    for item in authority:
        path = item.get("file", "")
        full = ROOT / path

        content = text(full)

        if not content:
            continue

        lower = content.lower()

        risk = []

        if "allow" in lower:
            risk.append("ALLOW_SURFACE")

        if "authorize" in lower:
            risk.append("AUTHORIZATION_SURFACE")

        if "grant" in lower:
            risk.append("GRANT_SURFACE")

        if "capability" in lower:
            risk.append("CAPABILITY_SURFACE")

        if "production_unlock" in lower:
            risk.append("PRODUCTION_UNLOCK_SURFACE")

        if "ul7rabridge" in lower:
            risk.append("BRIDGE_SURFACE")

        authority_review.append({
            "file": path,
            "risk_surfaces": sorted(set(risk)),
            "status": "REVIEW_REQUIRED",
            "authority_confirmed": False,
        })

    # ------------------------------------------------------------
    # 7. PROOF RISK REVIEW
    # ------------------------------------------------------------

    proof_review = []

    for item in proof:
        path = item.get("file", "")
        full = ROOT / path

        content = text(full)

        if not content:
            continue

        lower = content.lower()

        risk = []

        if "mint" in lower or "issue" in lower:
            risk.append("MINTING_SURFACE")

        if "verify" in lower:
            risk.append("VERIFICATION_SURFACE")

        if "ledger" in lower:
            risk.append("LEDGER_SURFACE")

        if "merkle" in lower:
            risk.append("MERKLE_SURFACE")

        if "nonce" in lower:
            risk.append("REPLAY_BOUNDARY")

        if "revoke" in lower:
            risk.append("REVOCATION_SURFACE")

        proof_review.append({
            "file": path,
            "risk_surfaces": sorted(set(risk)),
            "status": "REVIEW_REQUIRED",
            "proof_confirmed": False,
        })

    # ------------------------------------------------------------
    # 8. CONSOLIDATION ORDER
    # ------------------------------------------------------------

    phases = [
        {
            "phase": 1,
            "name": "FREEZE_AND_BASELINE",
            "action": "Record repository state and hashes.",
            "source_modification": False,
        },
        {
            "phase": 2,
            "name": "CANONICAL_COMPONENT_RESOLUTION",
            "action": "Resolve canonical vs duplicate vs legacy.",
            "source_modification": False,
        },
        {
            "phase": 3,
            "name": "AUTHORITY_BOUNDARY_RESOLUTION",
            "action": "Prove actual authority path to UL7RABRIDGE.",
            "source_modification": False,
        },
        {
            "phase": 4,
            "name": "PROOF_BOUNDARY_RESOLUTION",
            "action": "Separate evidence creation, verification and authority.",
            "source_modification": False,
        },
        {
            "phase": 5,
            "name": "DEPENDENCY_GRAPH_COMPLETION",
            "action": "Recover dependencies from actual manifests/imports/tests.",
            "source_modification": False,
        },
        {
            "phase": 6,
            "name": "REVERSIBLE_CONSOLIDATION",
            "action": "Only consolidate after regression baseline.",
            "source_modification": True,
        },
        {
            "phase": 7,
            "name": "PURPLE_TEAM_REGRESSION",
            "action": "Adversarially verify consolidated architecture.",
            "source_modification": True,
        },
        {
            "phase": 8,
            "name": "PRODUCTION_REVIEW",
            "action": "Independent governance decision.",
            "source_modification": False,
        },
    ]

    # ------------------------------------------------------------
    # 9. HARD GOVERNANCE INVARIANTS
    # ------------------------------------------------------------

    invariants = [
        "UNVERIFIED != PASS",
        "UNKNOWN remains UNKNOWN",
        "NO PROOF -> NO TRUSTED ACTION",
        "PROOF != AUTHORITY",
        "LUCI != AUTHORITY",
        "HALO9 != SOVEREIGN AUTHORITY",
        "AGENT != AUTHORITY",
        "COMMERCE != PROOF",
        "PAYMENT != PROOF",
        "CLOUD != SOVEREIGN AUTHORITY",
        "NO SELF CERTIFICATION",
        "FAIL CLOSED",
        "UL7RABRIDGE REMAINS FINAL AUTHORITY BOUNDARY",
        "NO PRODUCTION UNLOCK WITHOUT EVIDENCE",
        "NO SOURCE DELETION DURING DISCOVERY",
        "NO IRREVERSIBLE MIGRATION WITHOUT ROLLBACK",
    ]

    # ------------------------------------------------------------
    # 10. FINAL PHASE 3 PLAN
    # ------------------------------------------------------------

    result = {
        "phase": "PHASE3_EVIDENCE_BACKED_CONSOLIDATION_EXECUTION_PLAN",
        "decision": "REVIEW_REQUIRED",
        "source_modification": "NONE",
        "production_modification": "NONE",
        "production_unlock": "BLOCKED",
        "implementation_surfaces": implementation,
        "manifests": manifests,
        "critical_boundaries": boundaries,
        "duplicate_candidates": duplicate_candidates,
        "critical_components": critical_components,
        "authority_review": authority_review,
        "proof_review": proof_review,
        "execution_phases": phases,
        "security_invariants": invariants,
        "source_phase2": str(p2),
        "next_action": (
            "Resolve canonicality using actual source/manifests/tests "
            "before modifying implementation."
        ),
    }

    (out / "PHASE3_EXECUTION_PLAN.json").write_text(
        json.dumps(result, indent=2, sort_keys=True),
        encoding="utf-8",
    )

    (out / "DUPLICATE_CANDIDATES.json").write_text(
        json.dumps(duplicate_candidates, indent=2, sort_keys=True),
        encoding="utf-8",
    )

    (out / "AUTHORITY_REVIEW.json").write_text(
        json.dumps(authority_review, indent=2, sort_keys=True),
        encoding="utf-8",
    )

    (out / "PROOF_REVIEW.json").write_text(
        json.dumps(proof_review, indent=2, sort_keys=True),
        encoding="utf-8",
    )

    (out / "CRITICAL_COMPONENTS.json").write_text(
        json.dumps(critical_components, indent=2, sort_keys=True),
        encoding="utf-8",
    )

    (out / "EXECUTION_PHASES.json").write_text(
        json.dumps(phases, indent=2, sort_keys=True),
        encoding="utf-8",
    )

    report = f"""# UL7RAVERSE PHASE 3

DECISION=REVIEW_REQUIRED

IMPLEMENTATION_SURFACES={len(implementation)}
MANIFESTS={len(manifests)}
BOUNDARY_SURFACES={len(boundaries)}
DUPLICATE_CANDIDATES={len(duplicate_candidates)}
AUTHORITY_REVIEW_ITEMS={len(authority_review)}
PROOF_REVIEW_ITEMS={len(proof_review)}

SOURCE_MODIFICATION=NONE
PRODUCTION_MODIFICATION=NONE
REAL_UL7RABRIDGE_MODIFICATION=NONE
PRODUCTION_UNLOCK=BLOCKED

AUTHORITY_BOUNDARY=UL7RABRIDGE

GOVERNANCE:
UNVERIFIED_NEVER_PASS=ENFORCED
UNKNOWN_REMAINS_UNKNOWN=ENFORCED
PROOF_NOT_AUTHORITY=ENFORCED
LUCI_NOT_AUTHORITY=ENFORCED
HALO9_NOT_SOVEREIGN_AUTHORITY=ENFORCED
FAIL_CLOSED=ENFORCED
NO_SELF_CERTIFICATION=ENFORCED

NEXT_PHASE=CANONICALITY RESOLUTION AND REVERSIBLE CONSOLIDATION
"""

    (out / "PHASE3_REPORT.md").write_text(
        report,
        encoding="utf-8",
    )

    print("=== UL7RAVERSE PHASE 3 ===")
    print("PHASE3=COMPLETE")
    print("DECISION=REVIEW_REQUIRED")
    print("SOURCE_MODIFICATION=NONE")
    print("PRODUCTION_MODIFICATION=NONE")
    print("REAL_UL7RABRIDGE_MODIFICATION=NONE")
    print("PRODUCTION_UNLOCK=BLOCKED")
    print(f"IMPLEMENTATION_SURFACES={len(implementation)}")
    print(f"MANIFESTS={len(manifests)}")
    print(f"BOUNDARY_SURFACES={len(boundaries)}")
    print(f"DUPLICATE_CANDIDATES={len(duplicate_candidates)}")
    print(f"AUTHORITY_REVIEW_ITEMS={len(authority_review)}")
    print(f"PROOF_REVIEW_ITEMS={len(proof_review)}")
    print(f"OUTPUT={out}")
    print(f"REPORT={out / 'PHASE3_REPORT.md'}")

if __name__ == "__main__":
    sys.exit(main())
