#!/usr/bin/env python3

import os
import sys
import json
import subprocess
import datetime
import platform
import hashlib
from pathlib import Path

ROOT = Path(os.path.expanduser("~/UL7RAVERSE")).resolve()
MAX_FILE_SIZE = 50 * 1024 * 1024

FORBIDDEN_ENV_TOKENS = [
    "KEY", "TOKEN", "SECRET", "PASS", "PWD",
    "COOKIE", "AUTH", "CREDENTIAL"
]

SUBSYSTEM_NAMES = [
    "UL7RAVERSE",
    "UL7RAPROOF",
    "UL7RA4ORGE",
    "UL7RAFORGE",
    "UL7RABRIDGE",
    "UL7RASTACK",
    "NODE9",
    "TRINITY CORE",
    "SAIOS",
    "OmniShield",
    "OmniSentinel",
    "OmniBridge",
    "Proof State Engine",
    "Proof State Reactor",
    "Purple Protocol",
    "Protocol 52",
    "Continuous Verification",
    "LuciCore",
    "LuciVault",
    "LuciDeploy",
    "LUCI Test",
    "LUCI Diagnostic",
    "LUCI Agent",
    "LuciCoin",
    "LuciCare+",
    "LuciLaw",
    "LuciPet",
    "LuciLove",
    "LuciCate+",
    "FCOS",
    "FactIR",
    "HALO9",
    "Halo Twin",
    "Rolling Halo Lock",
    "Ghost Partition",
    "Cheetah",
    "PQC",
    "crypto agility",
    "racing/oracle",
    "membership",
    "commerce",
    "OmniValuation",
    "proof-state valuation",
]

SECURITY_PATTERNS = {
    "authority_grants": [
        "grant", "authorize", "allow", "permit", "role", "capability"
    ],
    "proof_minting": [
        "mint", "issue", "sign", "attest", "certify"
    ],
    "proof_verification": [
        "verify", "validate", "check", "proof", "evidence"
    ],
    "trust_decisions": [
        "trust", "trusted", "untrusted"
    ],
    "bridge_calls": [
        "bridge", "UL7RABRIDGE"
    ],
    "authentication": [
        "auth", "login", "token", "credential"
    ],
    "authorization": [
        "role", "permission", "acl"
    ],
    "privilege_inheritance": [
        "inherit", "escalate"
    ],
    "agent_replacement": [
        "replacement", "new agent", "rekey"
    ],
    "replay_protection": [
        "nonce", "replay", "sequence"
    ],
    "expiry": [
        "expire", "ttl"
    ],
    "revocation": [
        "revoke", "revokeall"
    ],
    "cryptographic_verification": [
        "sha256", "merkle", "signature", "verify"
    ],
    "ledger_verification": [
        "ledger", "journal", "audit"
    ],
    "external_network_calls": [
        "http://", "https://", "grpc", "tcp"
    ],
    "cloud_dependencies": [
        "aws", "gcp", "azure", "s3", "bucket"
    ],
    "credential_handling": [
        "password", "secret", "key"
    ],
    "persistence": [
        "sqlite", "postgres", "database", "write("
    ],
    "memory_retention": [
        "cache", "store", "remember"
    ],
}

PROOF_PATTERNS = {
    "claim_minting": ["claim", "mint", "issue"],
    "proof_creation": ["proof", "createproof", "create_proof", "generate_proof"],
    "proof_verification": ["verifyproof", "verify_proof", "validate_proof"],
    "ledger_writes": ["ledger", "append", "write"],
    "ledger_verification": ["verifyledger", "verify_ledger", "audit"],
    "hash_chains": ["hashchain", "hash_chain"],
    "merkle_structures": ["merkle"],
    "timestamps": ["timestamp", "time.time", "datetime"],
    "nonces": ["nonce"],
    "replay_state": ["replay"],
    "proof_state_transitions": ["proof_state", "state", "transition"],
}

ACTION_PATTERNS = [
    "http://",
    "https://",
    "grpc",
    "tcp",
    "os.system",
    "subprocess",
    "requests.",
    "fetch(",
    "exec(",
    "spawn(",
]

GATE_PATTERNS = [
    "haspermission",
    "is_authorized",
    "isauthorized",
    "checkpermission",
    "require_auth",
    "authorize",
    "permission",
    "capability",
]


def utc_stamp():
    return datetime.datetime.now(datetime.timezone.utc).strftime(
        "%Y%m%dT%H%M%SZ"
    )


def safe_run(cmd, cwd=None):
    try:
        result = subprocess.run(
            cmd,
            cwd=str(cwd) if cwd else None,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
        return {
            "cmd": cmd,
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
            "returncode": result.returncode,
        }
    except Exception as exc:
        return {
            "cmd": cmd,
            "stdout": "",
            "stderr": str(exc),
            "returncode": -1,
        }


def write_text(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def write_json(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(obj, indent=2, sort_keys=True),
        encoding="utf-8",
    )


def sha256_file(path):
    try:
        digest = hashlib.sha256()
        with path.open("rb") as fh:
            for chunk in iter(lambda: fh.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest()
    except Exception:
        return ""


def is_binary(path):
    try:
        with path.open("rb") as fh:
            return b"\0" in fh.read(4096)
    except Exception:
        return True


def safe_text(path):
    try:
        return path.read_text(
            encoding="utf-8",
            errors="ignore",
        )
    except Exception:
        return ""


def filtered_environment():
    result = {}

    for key, value in os.environ.items():
        upper = key.upper()

        if any(token in upper for token in FORBIDDEN_ENV_TOKENS):
            result[key] = "<REDACTED>"
        else:
            result[key] = value

    return result


def make_artifacts_root():
    path = (
        ROOT
        / "verification_artifacts"
        / "forensic_phase0"
        / utc_stamp()
    )
    path.mkdir(parents=True, exist_ok=True)
    return path


def discover_files():
    discovered = []

    for current_root, dirs, files in os.walk(ROOT):
        root_path = Path(current_root)

        dirs[:] = [
            d for d in dirs
            if not (root_path / d).is_symlink()
            and d not in {
                ".git",
                "target",
                "node_modules",
                "__pycache__",
            }
        ]

        for filename in files:
            path = root_path / filename

            try:
                if path.is_symlink():
                    continue

                size = path.stat().st_size

                if size > MAX_FILE_SIZE:
                    continue

            except Exception:
                continue

            discovered.append(path)

    return discovered


def classify_file(path):
    name = path.name.lower()
    rel = str(path.relative_to(ROOT))
    lower_rel = rel.lower()
    ext = path.suffix.lower()

    if path.name == "Cargo.toml":
        return "rust_crate_manifest"

    if path.name in {
        "pyproject.toml",
        "setup.py",
        "requirements.txt",
    }:
        return "python_project"

    if path.name == "package.json":
        return "javascript_project"

    if ext == ".sh":
        return "shell_script"

    if "test" in name or "spec" in name:
        return "test_surface"

    if (
        "policy" in name
        or "governance" in name
        or "invariant" in name
    ):
        return "policy_governance"

    if ext in {".yaml", ".yml", ".json", ".toml", ".ini"}:
        return "configuration"

    if ext in {".sql"} or "schema" in name:
        return "schema"

    if (
        "ledger" in name
        or "journal" in name
        or "merkle" in name
    ):
        return "ledger_or_log"

    if (
        "proof" in name
        or "evidence" in name
        or "hash" in name
    ):
        return "proof_artifact"

    if (
        "deploy" in name
        or "docker" in name
        or "k8s" in name
    ):
        return "deployment_artifact"

    if (
        "tunnel" in name
        or "proxy" in name
        or "vpn" in name
    ):
        return "network_boundary"

    if (
        "service" in name
        or "systemd" in name
        or "supervisor" in name
    ):
        return "service_definition"

    if any(x in lower_rel for x in ["legacy", "deprecated", "backup"]):
        return "legacy_or_backup_candidate"

    if (
        path.name.startswith("README")
        or ext == ".md"
        or "/docs/" in lower_rel
    ):
        return "documentation"

    return "source_or_other"


def inventory_components(paths):
    inventory = []

    for path in paths:
        rel = str(path.relative_to(ROOT))
        binary = is_binary(path)

        item = {
            "path": rel,
            "type": classify_file(path),
            "status": "DISCOVERED",
            "canonicality": "UNKNOWN",
            "purpose": "",
            "authority_level": "UNKNOWN",
            "trust_level": "UNKNOWN",
            "production_state": "UNKNOWN",
            "failure_behavior": "UNKNOWN",
            "entrypoints": [],
            "dependencies": [],
            "dependents": [],
            "proof_requirements": [],
            "crypto_requirements": [],
            "governance_requirements": [],
            "network_boundaries": [],
            "persistence": "UNKNOWN",
            "test_locations": [],
            "verification_artifacts": [],
            "source_hash": "" if binary else sha256_file(path),
            "git_reference": "",
            "notes": [
                "PHASE0_DISCOVERY_ONLY",
                "canonicality_not_inferred",
            ],
        }

        inventory.append(item)

    return inventory


def named_subsystems(paths):
    results = []

    for path in paths:
        rel = str(path.relative_to(ROOT))
        lower_rel = rel.lower().replace(" ", "")

        content = ""

        if not is_binary(path):
            content = safe_text(path).lower()

        for subsystem in SUBSYSTEM_NAMES:
            needle = subsystem.lower()

            path_match = needle.replace(" ", "") in lower_rel
            content_match = needle in content

            if path_match or content_match:
                results.append({
                    "subsystem": subsystem,
                    "path": rel,
                    "path_match": path_match,
                    "content_match": content_match,
                    "status": "DISCOVERED",
                    "canonicality": "UNKNOWN",
                    "notes": [
                        "Reference detected only.",
                        "Canonicality requires evidence.",
                    ],
                })

    return results


def security_surface(paths):
    surface = {
        key: []
        for key in SECURITY_PATTERNS
    }

    for path in paths:
        if is_binary(path):
            continue

        content = safe_text(path).lower()

        if not content:
            continue

        rel = str(path.relative_to(ROOT))

        for category, patterns in SECURITY_PATTERNS.items():
            hits = [
                pattern
                for pattern in patterns
                if pattern.lower() in content
            ]

            if hits:
                surface[category].append({
                    "file": rel,
                    "patterns": hits,
                })

    return surface


def authority_paths(paths):
    results = []

    for path in paths:
        if is_binary(path):
            continue

        content = safe_text(path).lower()

        if not content:
            continue

        action_hits = [
            pattern
            for pattern in ACTION_PATTERNS
            if pattern.lower() in content
        ]

        if not action_hits:
            continue

        gate_hits = [
            pattern
            for pattern in GATE_PATTERNS
            if pattern.lower() in content
        ]

        results.append({
            "file": str(path.relative_to(ROOT)),
            "action_patterns": action_hits,
            "gate_patterns": gate_hits,
            "gate_detected": bool(gate_hits),
            "classification": "AUTHORITY_REVIEW_REQUIRED",
            "notes": [
                "PHASE0 heuristic only.",
                "Presence does not prove authority.",
            ],
        })

    return results


def proof_paths(paths):
    results = []

    for path in paths:
        if is_binary(path):
            continue

        content = safe_text(path).lower()

        if not content:
            continue

        categories = []

        for category, patterns in PROOF_PATTERNS.items():
            if any(
                pattern.lower() in content
                for pattern in patterns
            ):
                categories.append(category)

        if categories:
            results.append({
                "file": str(path.relative_to(ROOT)),
                "categories": categories,
                "classification": "PROOF_REVIEW_REQUIRED",
                "notes": [
                    "PHASE0 heuristic only.",
                    "Pattern detection does not prove valid evidence.",
                ],
            })

    return results


def test_surfaces(paths):
    results = {
        "unit_tests": [],
        "integration_tests": [],
        "security_tests": [],
        "fuzzing": [],
        "adversarial_tests": [],
        "luci_tests": [],
        "diagnostic_tools": [],
        "independent_verifiers": [],
        "production_gates": [],
    }

    for path in paths:
        rel = str(path.relative_to(ROOT))
        lower = rel.lower()

        if not (
            "test" in lower
            or "spec" in lower
            or "verify" in lower
            or "diagnostic" in lower
            or "luci" in lower
            or "fuzz" in lower
            or "regression" in lower
            or "gate" in lower
        ):
            continue

        record = {
            "path": rel,
            "status": "DISCOVERED",
            "claim": "NONE",
        }

        if "luci" in lower and "test" in lower:
            results["luci_tests"].append(record)

        if "diagnostic" in lower:
            results["diagnostic_tools"].append(record)

        if "fuzz" in lower:
            results["fuzzing"].append(record)

        if "adversarial" in lower or "purple" in lower:
            results["adversarial_tests"].append(record)

        if "security" in lower:
            results["security_tests"].append(record)

        if "regression" in lower:
            results["integration_tests"].append(record)

        if "verify" in lower or "verifier" in lower:
            results["independent_verifiers"].append(record)

        if "gate" in lower:
            results["production_gates"].append(record)

        if "test" in lower or "spec" in lower:
            results["unit_tests"].append(record)

    return results


def existing_evidence(paths):
    evidence = []

    for path in paths:
        lower = str(path).lower()

        if any(
            token in lower
            for token in [
                "verification_artifacts",
                "evidence",
                "proof",
                "report",
                "audit",
                "forensic",
            ]
        ):
            evidence.append({
                "path": str(path.relative_to(ROOT)),
                "sha256": "" if is_binary(path) else sha256_file(path),
                "status": "EXISTING_EVIDENCE_CANDIDATE",
            })

    return evidence


def git_state():
    commands = {
        "status": ["git", "status", "--porcelain=v1"],
        "branch": ["git", "rev-parse", "--abbrev-ref", "HEAD"],
        "head": ["git", "rev-parse", "HEAD"],
        "recent_history": [
            "git", "log", "-n", "20", "--oneline"
        ],
        "worktrees": ["git", "worktree", "list"],
        "submodules": ["git", "submodule", "status"],
        "remotes": ["git", "remote", "-v"],
    }

    return {
        key: safe_run(command, ROOT)
        for key, command in commands.items()
    }


def environment_state():
    tools = {}

    for tool in [
        "rustc",
        "cargo",
        "python",
        "python3",
        "node",
        "npm",
        "git",
        "pytest",
        "z3",
        "z3-solver",
        "cloudflared",
        "gh",
    ]:
        tools[tool] = safe_run(
            [tool, "--version"],
            ROOT,
        )

    return {
        "timestamp_utc": utc_stamp(),
        "root": str(ROOT),
        "platform": platform.platform(),
        "system": platform.system(),
        "machine": platform.machine(),
        "python": platform.python_version(),
        "python_implementation": platform.python_implementation(),
        "tools": tools,
        "environment": filtered_environment(),
    }


def main():
    if not ROOT.exists():
        print(f"ROOT_NOT_FOUND={ROOT}")
        return 2

    artifacts = make_artifacts_root()

    print("=== UL7RAVERSE PHASE 0 FORENSIC DISCOVERY ===")
    print(f"ROOT={ROOT}")
    print(f"EVIDENCE={artifacts}")
    print("SOURCE_MODIFICATION=NONE")
    print("PRODUCTION_MODIFICATION=NONE")
    print()

    env = environment_state()
    write_json(
        artifacts / "ENVIRONMENT.json",
        env,
    )

    git = git_state()
    write_json(
        artifacts / "REPOSITORY_STATE.json",
        git,
    )

    paths = discover_files()

    inventory = inventory_components(paths)
    write_json(
        artifacts / "COMPONENT_INVENTORY.json",
        inventory,
    )

    subsystems = named_subsystems(paths)
    write_json(
        artifacts / "NAMED_SUBSYSTEMS.json",
        subsystems,
    )

    security = security_surface(paths)
    write_json(
        artifacts / "SECURITY_SURFACE.json",
        security,
    )

    authority = authority_paths(paths)
    write_json(
        artifacts / "AUTHORITY_PATHS.json",
        authority,
    )

    proof = proof_paths(paths)
    write_json(
        artifacts / "PROOF_PATHS.json",
        proof,
    )

    tests = test_surfaces(paths)
    write_json(
        artifacts / "TEST_SURFACES.json",
        tests,
    )

    evidence = existing_evidence(paths)
    write_json(
        artifacts / "EXISTING_EVIDENCE.json",
        evidence,
    )

    summary = {
        "phase": "PHASE0_FORENSIC_DISCOVERY",
        "decision": "REVIEW_REQUIRED",
        "claims": {
            "source_modification": "NONE",
            "production_modification": "NONE",
            "canonicality": "NOT_DETERMINED",
            "authority": "NOT_DETERMINED",
            "proof_validity": "NOT_DETERMINED",
            "production_readiness": "NOT_DETERMINED",
        },
        "counts": {
            "files_discovered": len(paths),
            "components": len(inventory),
            "subsystem_references": len(subsystems),
            "authority_candidates": len(authority),
            "proof_candidates": len(proof),
            "existing_evidence_candidates": len(evidence),
            "luci_test_candidates": len(tests["luci_tests"]),
            "diagnostic_candidates": len(tests["diagnostic_tools"]),
        },
        "governance": {
            "no_fabricated_pass": True,
            "unknown_remains_unknown": True,
            "proof_does_not_grant_authority": True,
            "phase0_read_only": True,
        },
    }

    write_json(
        artifacts / "PHASE0_SUMMARY.json",
        summary,
    )

    report = f"""UL7RAVERSE PHASE 0 FORENSIC DISCOVERY

UTC={summary["phase"]}
ROOT={ROOT}

SOURCE_MODIFICATION=NONE
PRODUCTION_MODIFICATION=NONE

DECISION=REVIEW_REQUIRED

CANONICALITY=NOT_DETERMINED
AUTHORITY=NOT_DETERMINED
PROOF_VALIDITY=NOT_DETERMINED
PRODUCTION_READINESS=NOT_DETERMINED

FILES_DISCOVERED={len(paths)}
COMPONENTS={len(inventory)}
SUBSYSTEM_REFERENCES={len(subsystems)}
AUTHORITY_CANDIDATES={len(authority)}
PROOF_CANDIDATES={len(proof)}
EXISTING_EVIDENCE_CANDIDATES={len(evidence)}
LUCI_TEST_CANDIDATES={len(tests["luci_tests"])}
DIAGNOSTIC_CANDIDATES={len(tests["diagnostic_tools"])}

GOVERNANCE:
NO_FABRICATED_PASS=ENFORCED
UNKNOWN_REMAINS_UNKNOWN=ENFORCED
PROOF_DOES_NOT_GRANT_AUTHORITY=ENFORCED
PHASE0_READ_ONLY=ENFORCED

NEXT_PHASE=EVIDENCE-BASED CANONICALITY / AUTHORITY / DEPENDENCY ANALYSIS
"""

    write_text(
        artifacts / "PHASE0_REPORT.txt",
        report,
    )

    print("PHASE0=COMPLETE")
    print("DECISION=REVIEW_REQUIRED")
    print("SOURCE_MODIFICATION=NONE")
    print("PRODUCTION_MODIFICATION=NONE")
    print(f"FILES_DISCOVERED={len(paths)}")
    print(f"COMPONENTS={len(inventory)}")
    print(f"SUBSYSTEM_REFERENCES={len(subsystems)}")
    print(f"AUTHORITY_CANDIDATES={len(authority)}")
    print(f"PROOF_CANDIDATES={len(proof)}")
    print(f"LUCI_TEST_CANDIDATES={len(tests['luci_tests'])}")
    print(f"DIAGNOSTIC_CANDIDATES={len(tests['diagnostic_tools'])}")
    print(f"REPORT={artifacts / 'PHASE0_REPORT.txt'}")
    print(f"EVIDENCE={artifacts}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
