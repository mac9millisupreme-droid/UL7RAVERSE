import json
from pathlib import Path

ROOT = Path("/data/data/com.termux/files/home/UL7RAVERSE")
APEX = Path("/data/data/com.termux/files/home/UL7RA4ORGE_APEX")
TRINITY = Path("/data/data/com.termux/files/home/TRINITY_CORE")

def discover():
    return {
        "ul7raverse_git": (ROOT / ".git").is_dir(),
        "apex_git": (APEX / ".git").is_dir(),
        "trinity_git": (TRINITY / ".git").is_dir(),
        "apex_provenance": (APEX / "evidence/apex_v0.4.1_provenance_anchor.json").exists(),
        "apex_attestation": (APEX / "evidence/apex_v0.4.1_attestation.json").exists(),
        "apex_promotion": (APEX / "evidence/apex_v0.4.1_promotion.json").exists()
    }

if __name__ == "__main__":
    print(json.dumps(discover(), indent=2, sort_keys=True))
