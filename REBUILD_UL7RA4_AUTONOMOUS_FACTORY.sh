#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT="$(pwd)"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/verification_artifacts/ul7ra4_factory/$TS"
FACTORY="$ROOT/ul7ra4_factory"

mkdir -p \
  "$OUT" \
  "$FACTORY"/{contracts,engine,gates,policies,reports,manifests,adapters} \
  "$ROOT/verification_artifacts/ul7ra4_factory"

exec > >(tee "$OUT/execution.log") 2>&1

echo "============================================================"
echo " UL7RA4 AUTONOMOUS FACTORY — REBUILD"
echo "============================================================"
echo "ROOT=$ROOT"
echo "TS=$TS"
echo

fail() {
  echo "FINAL_DECISION: BLOCKED"
  echo "REASON: $1"
  exit 1
}

command -v python >/dev/null 2>&1 || fail "python unavailable"
command -v git >/dev/null 2>&1 || fail "git unavailable"

# ------------------------------------------------------------
# 1. NEVER-DESTROY RULE
# ------------------------------------------------------------

cat > "$FACTORY/policies/DO_NOT_DESTROY.md" <<'EOF'
# UL7RA4 Factory — Preservation Policy

The factory MUST NOT:
- delete historical artifacts
- overwrite historical evidence
- rewrite forensic records
- fabricate verification
- promote from version number alone
- convert UNKNOWN to PASS
- convert UNVERIFIED to PASS
- treat execution as verification
- treat an offer as revenue
- self-certify production readiness

Historical implementations remain provenance.

Canonical promotion requires evidence.
EOF

# ------------------------------------------------------------
# 2. CANONICAL GOVERNANCE CONTRACT
# ------------------------------------------------------------

cat > "$FACTORY/contracts/governance.json" <<'EOF'
{
  "name": "UL7RA4_AUTONOMOUS_FACTORY_GOVERNANCE",
  "version": "1.0",
  "rules": {
    "unverified_never_pass": true,
    "unknown_remains_unknown": true,
    "fail_closed": true,
    "no_proof_no_trusted_action": true,
    "no_self_certification": true,
    "execution_does_not_equal_verification": true,
    "promotion_requires_evidence": true,
    "historical_artifacts_are_immutable": true,
    "commerce_proof_separation": true
  },
  "decision_states": [
    "PASS",
    "PASS_WITH_ENVIRONMENT_BLOCK",
    "UNVERIFIED",
    "UNKNOWN",
    "BLOCKED"
  ]
}
EOF

# ------------------------------------------------------------
# 3. FACTORY PIPELINE CONTRACT
# ------------------------------------------------------------

cat > "$FACTORY/contracts/pipeline.json" <<'EOF'
{
  "pipeline": [
    "INTAKE",
    "INVENTORY",
    "CLASSIFY",
    "DEPENDENCY_MAP",
    "BUILD",
    "UNIT_TEST",
    "INTEGRATION_TEST",
    "ADVERSARIAL_TEST",
    "PROVENANCE_CHECK",
    "INTEGRITY_CHECK",
    "EVIDENCE_PACKAGE",
    "STATUS_REPORT",
    "PROMOTION_GATE"
  ],
  "promotion_rule": "EVIDENCE_REQUIRED"
}
EOF

# ------------------------------------------------------------
# 4. IMMUTABLE FORENSIC INVENTORY
# ------------------------------------------------------------

echo "[1/8] Building forensic inventory..."

{
  echo "UL7RA4 FACTORY FORENSIC INVENTORY"
  echo "UTC=$TS"
  echo

  echo "=== GIT ==="
  git rev-parse --show-toplevel 2>/dev/null || true
  git rev-parse HEAD 2>/dev/null || true
  git status --short 2>/dev/null || true

  echo
  echo "=== BRANCHES ==="
  git branch -a 2>/dev/null || true

  echo
  echo "=== TAGS ==="
  git tag --list 2>/dev/null || true

  echo
  echo "=== VERSION-LIKE PATHS ==="
  find . \
    -path './.git' -prune -o \
    \( -iname '*v155*' -o \
       -iname '*v99*' -o \
       -iname '*v10*' -o \
       -iname '*v09*' -o \
       -iname '*v06*' -o \
       -iname '*apex*' -o \
       -iname '*genesis*' -o \
       -iname '*forge*' \) \
    -print 2>/dev/null | sort

  echo
  echo "=== MAJOR SYSTEM SURFACES ==="
  find . \
    -path './.git' -prune -o \
    \( -iname '*ul7ra*' -o \
       -iname '*luci*' -o \
       -iname '*purple*' -o \
       -iname '*sentinel*' -o \
       -iname '*proof*' -o \
       -iname '*bridge*' -o \
       -iname '*trinity*' -o \
       -iname '*node9*' -o \
       -iname '*saios*' -o \
       -iname '*racing*' -o \
       -iname '*membership*' -o \
       -iname '*enterprise*' \) \
    -print 2>/dev/null | sort

  echo
  echo "=== HASH MANIFEST ==="
  find . \
    -path './.git' -prune -o \
    -type f -print0 2>/dev/null |
    sort -z |
    xargs -0 sha256sum 2>/dev/null || true

} > "$OUT/FORENSIC_INVENTORY.txt"

# ------------------------------------------------------------
# 5. CANONICAL COMPONENT REGISTER
# ------------------------------------------------------------

echo "[2/8] Creating canonical component register..."

cat > "$FACTORY/manifests/CANONICAL_COMPONENT_REGISTER.json" <<'EOF'
{
  "canonical_root": "UL7RAVERSE",
  "factory": "UL7RA4_AUTONOMOUS_FACTORY",
  "components": {
    "governance": [
      "Trinity Core",
      "EVI",
      "SAIOS",
      "NODE9",
      "FCOS"
    ],
    "engineering": [
      "UL7RA4ORGE"
    ],
    "infrastructure": [
      "UL7RABRIDGE",
      "UL7RASTACK",
      "UL7RASENTINEL"
    ],
    "proof": [
      "UL7RAPROOF",
      "Proof State Engine",
      "Proof-State Reports",
      "Continuous Verification"
    ],
    "verification": [
      "UL7RA Verify",
      "V99-LITE",
      "V155"
    ],
    "security": [
      "OmniShield",
      "OmniSentinel",
      "OmniBridge",
      "Purple Team",
      "Protocol 52"
    ],
    "luci": [
      "LuciCore",
      "LuciVault",
      "LuciDeploy",
      "LUCI Diagnostic",
      "LUCI Test",
      "LUCIAGENT3",
      "LUCIcoin"
    ],
    "applications": [
      "Racing Oracle",
      "Race-State Reconstruction",
      "Latent Horse Ability"
    ],
    "commercial": [
      "UL7RAPASS",
      "Enterprise",
      "Commerce",
      "E6"
    ],
    "media": [
      "MAC9RECORDS",
      "Insight",
      "GQ FADER"
    ]
  },
  "classification_rule": {
    "CANONICAL": "evidence-backed current implementation",
    "CANDIDATE": "implementation requiring reconciliation",
    "HISTORICAL": "preserved prior generation",
    "UNVERIFIED": "claimed or present without sufficient evidence",
    "MISSING": "referenced but not found in current inventory"
  }
}
EOF

# ------------------------------------------------------------
# 6. BUILD ENGINE
# ------------------------------------------------------------

echo "[3/8] Installing factory engine..."

cat > "$FACTORY/engine/factory.py" <<'PY'
#!/usr/bin/env python3
import json
import hashlib
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FACTORY = ROOT / "ul7ra4_factory"

def now():
    return datetime.now(timezone.utc).isoformat()

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

def git(*args):
    try:
        return subprocess.check_output(
            ["git", *args],
            cwd=ROOT,
            stderr=subprocess.STDOUT,
            text=True
        ).strip()
    except Exception as e:
        return f"ERROR:{e}"

def inventory():
    result = {
        "timestamp": now(),
        "root": str(ROOT),
        "git_head": git("rev-parse", "HEAD"),
        "git_branch": git("branch", "--show-current"),
        "git_status": git("status", "--short"),
        "files": []
    }

    excluded = {".git", "__pycache__"}

    for p in ROOT.rglob("*"):
        if not p.is_file():
            continue
        if any(part in excluded for part in p.parts):
            continue
        try:
            result["files"].append({
                "path": str(p.relative_to(ROOT)),
                "sha256": sha256(p),
                "bytes": p.stat().st_size
            })
        except Exception:
            pass

    return result

def main():
    data = inventory()

    out = FACTORY / "manifests" / "CURRENT_BUILD_MANIFEST.json"
    out.parent.mkdir(parents=True, exist_ok=True)

    tmp = out.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2, sort_keys=True))
    os.replace(tmp, out)

    print(json.dumps({
        "factory": "UL7RA4_AUTONOMOUS_FACTORY",
        "timestamp": data["timestamp"],
        "git_head": data["git_head"],
        "file_count": len(data["files"]),
        "manifest": str(out)
    }, indent=2))

if __name__ == "__main__":
    main()
PY

chmod +x "$FACTORY/engine/factory.py"

# ------------------------------------------------------------
# 7. EXECUTION
# ------------------------------------------------------------

echo "[4/8] Running canonical inventory..."
python "$FACTORY/engine/factory.py"

echo "[5/8] Running available repository tests..."

TEST_STATUS=PASS

if command -v pytest >/dev/null 2>&1; then
  if pytest -q; then
    TEST_STATUS=PASS
  else
    TEST_STATUS=FAIL
  fi
elif [ -f "Cargo.toml" ] && command -v cargo >/dev/null 2>&1; then
  if cargo test --all; then
    TEST_STATUS=PASS
  else
    TEST_STATUS=FAIL
  fi
else
  TEST_STATUS=UNKNOWN
fi

# ------------------------------------------------------------
# 8. FINAL DECISION — NEVER SELF-PROMOTE
# ------------------------------------------------------------

echo "[6/8] Generating final status..."

HEAD="$(git rev-parse HEAD 2>/dev/null || echo UNKNOWN)"
DIRTY="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"

DECISION="UNVERIFIED"
REASON="Canonical factory rebuilt and inventory generated; promotion requires evidence beyond execution."

if [ "$TEST_STATUS" = "FAIL" ]; then
  DECISION="BLOCKED"
  REASON="Available test suite failed."
elif [ "$TEST_STATUS" = "UNKNOWN" ]; then
  DECISION="UNVERIFIED"
  REASON="No supported test runner was available."
elif [ "$TEST_STATUS" = "PASS" ]; then
  DECISION="PASS_WITH_ENVIRONMENT_BLOCK"
  REASON="Available tests passed, but this run does not independently establish production/commercial/external verification."
fi

cat > "$OUT/MASTER_SYSTEM_STATUS.md" <<EOF
# UL7RA4 AUTONOMOUS FACTORY — MASTER SYSTEM STATUS

UTC: $TS

## Canonical System

UL7RAVERSE

## Factory

UL7RA4 AUTONOMOUS FACTORY

## Git

HEAD: $HEAD
Working-tree changed paths: $DIRTY

## Test Status

$TEST_STATUS

## Governance

- UNVERIFIED never PASS
- UNKNOWN remains UNKNOWN
- Fail closed
- No proof -> trusted action
- No self-certification
- Execution != verification
- Historical evidence preserved
- Promotion requires evidence

## V155

V155 is included in the canonical reconciliation register.

Version number alone does not authorize promotion.

## Commercial State

This factory run does NOT establish live revenue.

Offer != sale.
Payment intent != payment.
Payment != activation.
Activation != verified membership.

## FINAL_DECISION

$DECISION

## REASON

$REASON
EOF

# ------------------------------------------------------------
# FINAL HASHED EVIDENCE
# ------------------------------------------------------------

echo "[7/8] Hashing factory evidence..."

find "$OUT" -type f -print0 |
  sort -z |
  xargs -0 sha256sum > "$OUT/EVIDENCE_SHA256SUMS.txt"

cat > "$OUT/FINAL_DECISION.txt" <<EOF
UL7RA4 AUTONOMOUS FACTORY

FINAL_DECISION: $DECISION
TEST_STATUS: $TEST_STATUS
GIT_HEAD: $HEAD
UTC: $TS

$REASON
EOF

echo "[8/8] Complete."
echo
echo "============================================================"
cat "$OUT/FINAL_DECISION.txt"
echo "============================================================"
echo
echo "EVIDENCE: $OUT"
echo "FACTORY:  $FACTORY"
