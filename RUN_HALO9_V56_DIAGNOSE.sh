#!/data/data/com.termux/files/usr/bin/bash
set -u

ROOT="$HOME/UL7RAVERSE"
PROJECT="$ROOT/halo9_v56_authority_contract"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/verification_artifacts/halo9_v56_diagnostic/$TS"
LOG="$OUT/compiler.log"

mkdir -p "$OUT"

echo "=================================================="
echo "HALO9 V56 — LIGHTWEIGHT COMPILER DIAGNOSTIC"
echo "UTC=$TS"
echo "=================================================="
echo "PROJECT=$PROJECT"
echo "REAL_BRIDGE_MODIFICATION=NONE"
echo "REAL_BRIDGE_INTEGRATION=NOT_PERFORMED"
echo ""

cd "$PROJECT" || exit 1

echo "=== CARGO CHECK ==="
cargo check 2>&1 | tee "$LOG"
CHECK_RC=${PIPESTATUS[0]}

echo ""
echo "=================================================="
echo "COMPILER ERROR EXTRACTION"
echo "=================================================="

grep -E \
'error\[E[0-9]+\]|error:| --> src/|help:|note:|could not compile' \
"$LOG" | tail -n 100

echo ""
echo "=================================================="
echo "RESULT"
echo "=================================================="
echo "CARGO_CHECK_RC=$CHECK_RC"
echo "REAL_BRIDGE_MODIFICATION=NONE"
echo "PRODUCTION_CRYPTO=NOT_CONFIGURED"
echo "PRODUCTION_UNLOCK=BLOCKED"
echo "DIAGNOSTIC=$OUT"
echo "=================================================="

exit "$CHECK_RC"
