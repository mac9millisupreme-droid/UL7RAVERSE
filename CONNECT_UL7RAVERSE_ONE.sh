#!/data/data/com.termux/files/usr/bin/bash
set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/verification_artifacts/unified/ONE_EXECUTION_$TS"

mkdir -p "$OUT"
exec > >(tee "$OUT/EXECUTION.log") 2>&1

cd "$ROOT" || exit 1

echo "=== UL7RAVERSE ONE EXECUTION ==="
echo "ROOT=$ROOT"
echo "TIMESTAMP=$TS"
echo "HEAD=$(git rev-parse HEAD)"
echo "BRANCH=$(git branch --show-current)"
echo

git status --short > "$OUT/GIT_STATUS.txt"

echo "=== TEST SURFACE DISCOVERY ==="

PYTEST_DIRS="$(find "$ROOT" \
  -type d -name tests \
  -not -path '*/.git/*' \
  -not -path '*/verification_artifacts/*' \
  -print 2>/dev/null)"

CARGO_FILES="$(find "$ROOT" \
  -name Cargo.toml \
  -not -path '*/.git/*' \
  -not -path '*/verification_artifacts/*' \
  -print 2>/dev/null)"

NODE_FILES="$(find "$ROOT" \
  -name package.json \
  -not -path '*/node_modules/*' \
  -not -path '*/.git/*' \
  -not -path '*/verification_artifacts/*' \
  -print 2>/dev/null)"

printf '%s\n' "$PYTEST_DIRS" > "$OUT/PYTEST_DIRS.txt"
printf '%s\n' "$CARGO_FILES" > "$OUT/CARGO_FILES.txt"
printf '%s\n' "$NODE_FILES" > "$OUT/NODE_FILES.txt"

cat "$OUT/PYTEST_DIRS.txt"
cat "$OUT/CARGO_FILES.txt"
cat "$OUT/NODE_FILES.txt"

TEST_EXIT=0
TEST_RUN="NONE"

echo
echo "=== PYTHON TESTS ==="

if [ -n "$PYTEST_DIRS" ] && command -v pytest >/dev/null 2>&1; then
    TEST_RUN="PYTEST"
    pytest -q
    TEST_EXIT=$?
else
    echo "PYTEST_NOT_SELECTED"
fi

echo
echo "=== RUST TESTS ==="

if [ "$TEST_EXIT" -eq 0 ] && [ -n "$CARGO_FILES" ] && command -v cargo >/dev/null 2>&1; then
    TEST_RUN="${TEST_RUN}+CARGO"
    while IFS= read -r CARGO; do
        [ -z "$CARGO" ] && continue
        D="$(dirname "$CARGO")"
        echo "CARGO_PROJECT=$D"
        (
            cd "$D" && cargo test
        ) || TEST_EXIT=$?
    done <<EOF
$CARGO_FILES
EOF
fi

echo
echo "=== NODE TESTS ==="

if [ "$TEST_EXIT" -eq 0 ] && [ -n "$NODE_FILES" ] && command -v npm >/dev/null 2>&1; then
    while IFS= read -r PKG; do
        [ -z "$PKG" ] && continue
        D="$(dirname "$PKG")"

        if grep -q '"test"' "$PKG" 2>/dev/null; then
            TEST_RUN="${TEST_RUN}+NPM"
            echo "NPM_PROJECT=$D"
            (
                cd "$D" && npm test
            ) || TEST_EXIT=$?
        fi
    done <<EOF
$NODE_FILES
EOF
fi

echo
echo "TEST_RUN=$TEST_RUN"
echo "TEST_EXIT=$TEST_EXIT"

echo
echo "=== COMPONENT INVENTORY ==="

COMPONENTS="
UL7RA4ORGE
UL7RAPROOF
UL7RABRIDGE
UL7RASTACK
UL7RASENTINEL
NODE9
TRINITY
LUCI
PURPLE
RACING
UL7RA_VERIFY
V99-LITE
V155
"

: > "$OUT/COMPONENT_STATUS.tsv"

for C in $COMPONENTS; do
    COUNT="$(find "$ROOT" \
        -not -path '*/.git/*' \
        -not -path '*/verification_artifacts/*' \
        -iname "*${C}*" \
        -print 2>/dev/null | wc -l | tr -d ' ')"

    if [ "$COUNT" -gt 0 ]; then
        STATUS="PATH_FOUND"
    else
        STATUS="PATH_NOT_FOUND"
    fi

    printf '%s|%s|%s|CANONICAL_NOT_PROMOTED\n' \
      "$C" "$STATUS" "$COUNT" | tee -a "$OUT/COMPONENT_STATUS.tsv"
done

echo
echo "=== SOURCE HASH ==="

find "$ROOT" -type f \
  \( -name '*.py' -o -name '*.rs' -o -name '*.js' -o -name '*.ts' \
     -o -name '*.json' -o -name '*.sh' \) \
  -not -path '*/.git/*' \
  -not -path '*/verification_artifacts/*' \
  -print0 |
sort -z |
xargs -0 sha256sum > "$OUT/SOURCE_SHA256SUMS.txt"

echo "SOURCE_HASHES=$(wc -l < "$OUT/SOURCE_SHA256SUMS.txt")"

echo
echo "=== FAIL-CLOSED DECISION ==="

if [ "$TEST_EXIT" -eq 0 ] && [ -n "$TEST_RUN" ] && [ "$TEST_RUN" != "NONE" ]; then
    TEST_STATUS="PASS"
    FINAL="PASS_WITH_ENVIRONMENT_BLOCK"
else
    TEST_STATUS="BLOCKED"
    FINAL="BLOCKED"
fi

CANONICAL_PROMOTION="BLOCKED"

cat > "$OUT/FINAL_DECISION.md" <<EOF
# UL7RAVERSE ONE EXECUTION

TIMESTAMP: $TS
HEAD: $(git rev-parse HEAD)
BRANCH: $(git branch --show-current)

TEST_RUN: $TEST_RUN
TEST_STATUS: $TEST_STATUS
CANONICAL_PROMOTION: $CANONICAL_PROMOTION

GOVERNANCE:
- UNVERIFIED_NEVER_PASS
- UNKNOWN_REMAINS_UNKNOWN
- NO_PROOF_NO_TRUSTED_ACTION
- NO_SELF_CERTIFICATION
- FAIL_CLOSED

Historical artifacts were not deleted or moved.

PATH_FOUND is not implementation proof.

FINAL_DECISION: $FINAL
EOF

cat "$OUT/FINAL_DECISION.md"

echo
echo "EVIDENCE=$OUT"
