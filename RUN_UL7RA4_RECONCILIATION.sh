#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT="$(pwd)"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
BASE="$ROOT/verification_artifacts/ul7ra4_factory/20260911T185311Z"
OUT="$ROOT/verification_artifacts/ul7ra4_factory/reconciliation_$TS"

mkdir -p "$OUT"

exec > >(tee "$OUT/reconciliation.log") 2>&1

echo "============================================================"
echo " UL7RA4 AUTONOMOUS FACTORY — FORENSIC RECONCILIATION"
echo "============================================================"
echo "ROOT=$ROOT"
echo "BASE=$BASE"
echo "OUT=$OUT"
echo

fail_closed() {
    echo "FINAL_DECISION: BLOCKED"
    echo "REASON: $1"
    exit 1
}

[ -d "$BASE" ] || fail_closed "Baseline factory evidence directory missing."

# ------------------------------------------------------------
# 1. CURRENT CANONICAL STATE
# ------------------------------------------------------------

echo "=== CANONICAL BASELINE ==="

{
    echo "GIT_HEAD=$(git rev-parse HEAD)"
    echo "BRANCH=$(git branch --show-current)"
    echo "STATUS:"
    git status --short
    echo
    echo "REMOTE:"
    git remote -v
} > "$OUT/CANONICAL_GIT_STATE.txt"

cat "$OUT/CANONICAL_GIT_STATE.txt"

# ------------------------------------------------------------
# 2. EXTRACT ALL VERSION / COMPONENT SURFACES
# ------------------------------------------------------------

echo
echo "=== VERSION SURFACES ==="

find . \
    -path './.git' -prune -o \
    -type f \
    \( \
      -iname '*v155*' -o \
      -iname '*v99*' -o \
      -iname '*v10*' -o \
      -iname '*v09*' -o \
      -iname '*v06*' -o \
      -iname '*apex*' -o \
      -iname '*genesis*' -o \
      -iname '*forge*' \
    \) \
    -print 2>/dev/null | sort -u \
    > "$OUT/VERSION_SURFACES.txt"

cat "$OUT/VERSION_SURFACES.txt"

# ------------------------------------------------------------
# 3. EXTRACT ALL MAJOR COMPONENT SURFACES
# ------------------------------------------------------------

echo
echo "=== COMPONENT SURFACES ==="

find . \
    -path './.git' -prune -o \
    -type f \
    \( \
      -iname '*ul7ra*' -o \
      -iname '*proof*' -o \
      -iname '*bridge*' -o \
      -iname '*stack*' -o \
      -iname '*sentinel*' -o \
      -iname '*shield*' -o \
      -iname '*trinity*' -o \
      -iname '*evi*' -o \
      -iname '*saios*' -o \
      -iname '*node9*' -o \
      -iname '*luci*' -o \
      -iname '*purple*' -o \
      -iname '*racing*' -o \
      -iname '*membership*' -o \
      -iname '*enterprise*' \
    \) \
    -print 2>/dev/null | sort -u \
    > "$OUT/COMPONENT_SURFACES.txt"

cat "$OUT/COMPONENT_SURFACES.txt"

# ------------------------------------------------------------
# 4. EXACT V155 SEARCH
# ------------------------------------------------------------

echo
echo "=== V155 FORENSIC SEARCH ==="

{
    echo "=== PATHS ==="
    find . -path './.git' -prune -o \
        \( -iname '*155*' -o -iname '*v155*' \) \
        -print 2>/dev/null | sort

    echo
    echo "=== CONTENT REFERENCES ==="
    grep -RniE \
        --exclude-dir=.git \
        --exclude-dir=__pycache__ \
        --exclude='*.pyc' \
        'V155|v155|UL7RA4|UL7RAFORGE|UL7RASENTINEL|UL7RAPROOF|UL7RABRIDGE' \
        . 2>/dev/null | head -n 500
} > "$OUT/V155_FORENSIC.txt"

cat "$OUT/V155_FORENSIC.txt"

# ------------------------------------------------------------
# 5. COMPONENT REGISTER
# ------------------------------------------------------------

echo
echo "=== COMPONENT REGISTER ==="

python - "$OUT/COMPONENT_REGISTER.json" <<'PY'
import json
import os
import sys
from pathlib import Path

root = Path.cwd()
out = Path(sys.argv[1])

components = {
    "governance": [
        "Trinity Core", "EVI", "SAIOS", "NODE9", "FCOS",
        "Governance", "Proof State Engine"
    ],
    "engineering": [
        "UL7RA4ORGE", "UL7RAFORGE", "V155", "V99-LITE"
    ],
    "infrastructure": [
        "UL7RABRIDGE", "UL7RASTACK", "UL7RASENTINEL",
        "UL7RA Verify"
    ],
    "proof": [
        "UL7RAPROOF", "Continuous Verification",
        "Proof-State Reports"
    ],
    "security": [
        "OmniShield", "OmniSentinel", "OmniBridge",
        "Purple Team", "Protocol 52"
    ],
    "luci": [
        "LuciCore", "LuciVault", "LuciDeploy",
        "LUCI Diagnostic", "LUCI Test",
        "LUCIAGENT3", "LUCIcoin"
    ],
    "applications": [
        "Racing Oracle", "Race-State Reconstruction",
        "Latent Horse Ability"
    ],
    "commercial": [
        "UL7RAPASS", "Enterprise", "Commerce", "E6"
    ],
    "media": [
        "MAC9RECORDS", "Insight", "GQ FADER"
    ]
}

all_files = []
for p in root.rglob("*"):
    if p.is_file() and ".git" not in p.parts:
        all_files.append(str(p.relative_to(root)))

def matches(name):
    tokens = name.lower().replace("-", " ").split()
    hits = []
    for f in all_files:
        lf = f.lower()
        if any(t in lf for t in tokens if len(t) > 2):
            hits.append(f)
    return sorted(set(hits))[:100]

result = {
    "root": str(root),
    "components": {}
}

for category, names in components.items():
    result["components"][category] = {}
    for name in names:
        paths = matches(name)
        result["components"][category][name] = {
            "filesystem_matches": paths,
            "classification": (
                "FOUND_SURFACE" if paths else "NOT_FOUND_IN_CURRENT_PATH"
            )
        }

out.write_text(json.dumps(result, indent=2, sort_keys=True))
print(json.dumps(result, indent=2))
PY

# ------------------------------------------------------------
# 6. DEPENDENCY / BUILD GRAPH
# ------------------------------------------------------------

echo
echo "=== BUILD GRAPH ==="

cat > "$OUT/BUILD_GRAPH.json" <<'JSON'
{
  "root": "OMNILUCIENT",
  "canonical": "UL7RAVERSE",
  "layers": {
    "governance": [
      "Trinity Core",
      "EVI",
      "SAIOS",
      "NODE9",
      "FCOS"
    ],
    "construction": [
      "UL7RA4ORGE"
    ],
    "infrastructure": [
      "UL7RABRIDGE",
      "UL7RASTACK",
      "UL7RASENTINEL"
    ],
    "proof": [
      "UL7RAPROOF",
      "UL7RA Verify",
      "Continuous Verification",
      "Proof-State Reports"
    ],
    "adversarial": [
      "OmniShield",
      "OmniSentinel",
      "OmniBridge",
      "LUCI",
      "Purple Team"
    ],
    "runtime_profiles": [
      "V99-LITE",
      "V155"
    ],
    "applications": [
      "Racing Oracle"
    ],
    "commercial": [
      "UL7RAPASS",
      "Enterprise",
      "Commerce"
    ],
    "distribution": [
      "MAC9RECORDS",
      "Insight",
      "GQ FADER"
    ]
  }
}
JSON

# ------------------------------------------------------------
# 7. TEST CURRENT STATE AGAIN
# ------------------------------------------------------------

echo
echo "=== REGRESSION TEST ==="

TEST_RESULT="UNKNOWN"

if command -v pytest >/dev/null 2>&1; then
    if pytest -q; then
        TEST_RESULT="PASS"
    else
        TEST_RESULT="FAIL"
    fi
elif [ -f Cargo.toml ] && command -v cargo >/dev/null 2>&1; then
    if cargo test --all; then
        TEST_RESULT="PASS"
    else
        TEST_RESULT="FAIL"
    fi
fi

echo "TEST_RESULT=$TEST_RESULT" | tee "$OUT/TEST_RESULT.txt"

# ------------------------------------------------------------
# 8. PROMOTION GATE
# ------------------------------------------------------------

echo
echo "=== PROMOTION GATE ==="

DECISION="UNVERIFIED"
REASON="Reconciliation inventory completed; component-level promotion evidence has not yet been independently established."

if [ "$TEST_RESULT" = "FAIL" ]; then
    DECISION="BLOCKED"
    REASON="Current regression suite failed."
elif [ "$TEST_RESULT" = "PASS" ]; then
    DECISION="PASS_WITH_ENVIRONMENT_BLOCK"
    REASON="Current regression suite passes, but reconciliation does not automatically promote historical/candidate components."
fi

cat > "$OUT/MASTER_RECONCILIATION_STATUS.md" <<EOF
# UL7RA4 AUTONOMOUS FACTORY — RECONCILIATION STATUS

UTC: $TS

## Canonical Root

UL7RAVERSE

## Git HEAD

$(git rev-parse HEAD)

## Inventory Baseline

2,228 files at 20260911T185311Z.

## Current Regression

$TEST_RESULT

## V155

V155 is explicitly tracked as a candidate/version surface.
No promotion occurs from version number alone.

## Promotion Doctrine

- UNKNOWN remains UNKNOWN.
- UNVERIFIED never PASS.
- EXECUTED != VERIFIED.
- Historical artifacts remain preserved.
- No automatic promotion without evidence.
- No deletion or destructive migration performed.

## FINAL_DECISION

$DECISION

## REASON

$REASON
EOF

# ------------------------------------------------------------
# 9. HASH EVERYTHING
# ------------------------------------------------------------

find "$OUT" -type f -print0 |
    sort -z |
    xargs -0 sha256sum > "$OUT/EVIDENCE_SHA256SUMS.txt"

echo
echo "============================================================"
echo "RECONCILIATION COMPLETE"
echo "FINAL_DECISION: $DECISION"
echo "TEST_RESULT: $TEST_RESULT"
echo "EVIDENCE: $OUT"
echo "============================================================"
