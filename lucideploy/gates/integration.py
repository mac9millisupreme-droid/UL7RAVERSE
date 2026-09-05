from dataclasses import dataclass
from pathlib import Path
import json


@dataclass(frozen=True)
class IntegrationResult:
    artifact_identity: bool
    sha256_integrity: bool
    provenance: bool
    governance: bool
    deterministic_verification: bool
    deployment_prerequisites: bool
    production: bool


def evaluate(root: Path) -> IntegrationResult:
    apex = Path.home() / "UL7RA4ORGE_APEX"
    trinity = Path.home() / "TRINITY_CORE"
    product = root / "products" / "ul7ra-verify"

    artifact_identity = (
        (apex / "VERSION").exists()
        and (apex / "evidence/apex_v0.4.1_promotion.json").exists()
    )

    sha256_integrity = (apex / "ul7ra/core.py").exists()

    provenance = (
        (apex / "evidence/apex_v0.4.1_provenance_anchor.json").exists()
        and not (apex / ".git").exists()
    )

    governance = (
        (trinity / ".git").exists()
        and (trinity / "PROVENANCE.json").exists()
        and (trinity / "governance/STATE.json").exists()
    )

    deterministic_verification = (
        (apex / "scripts/real_attack_suite.py").exists()
        and (apex / "tests/test_core.py").exists()
    )

    deployment_prerequisites = (
        (product / "PRODUCT_CONTRACT.json").exists()
        and (product / "scripts/verify_product.sh").exists()
        and (product / "deploy/start_local.sh").exists()
    )

    # Production intentionally remains false until independent hostname
    # /health and /verify evidence is actually generated.
    production = False

    return IntegrationResult(
        artifact_identity,
        sha256_integrity,
        provenance,
        governance,
        deterministic_verification,
        deployment_prerequisites,
        production,
    )


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[2]
    result = evaluate(root)
    print(json.dumps(result.__dict__, indent=2, sort_keys=True))
