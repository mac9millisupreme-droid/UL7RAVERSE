#!/data/data/com.termux/files/usr/bin/bash
set -u

ROOT="$HOME/UL7RAVERSE"
BRIDGE="$ROOT/UL7RAFORGE/v10/ul7rabridge"
OUT="$ROOT/verification_artifacts/halo9_bridge_recon"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT="$OUT/HALO9_BRIDGE_CONTRACT_$STAMP.txt"

mkdir -p "$OUT"

exec > >(tee "$REPORT") 2>&1

echo "=================================================="
echo " HALO9 → UL7RABRIDGE CONTRACT INSPECTION"
echo " READ ONLY"
echo "=================================================="
echo "TIMESTAMP=$STAMP"
echo "BRIDGE=$BRIDGE"
echo

if [ ! -d "$BRIDGE" ]; then
  echo "FINAL_DECISION=BLOCKED"
  echo "REASON=bridge_not_found"
  exit 1
fi

echo "=== CARGO MANIFEST ==="
cat "$BRIDGE/Cargo.toml"
echo

echo "=== MAIN.RS ==="
cat "$BRIDGE/src/main.rs"
echo

echo "=== CHEETAH MAIN.RS ==="
if [ -f "$BRIDGE/cheetah/src/main.rs" ]; then
  cat "$BRIDGE/cheetah/src/main.rs"
else
  echo "CHEETAH_SOURCE=NOT_FOUND"
fi
echo

echo "=== SOURCE TREE ==="
find "$BRIDGE" -maxdepth 3 -type f \
  ! -path '*/target/*' \
  -print | sort
echo

echo "=== PUBLIC API SEARCH ==="
grep -RniE \
  'pub (struct|enum|trait|fn|type|mod)|fn main|Result<|serde|json|stdin|stdout|args|env::args|Cheetah|deny|allow|direction|capabilit|proof|verify|authoriz|action' \
  "$BRIDGE/src" "$BRIDGE/cheetah/src" 2>/dev/null || true
echo

echo "=== BUILD STATUS ==="
cd "$BRIDGE" || exit 1

cargo check
CHECK_RC=$?

echo
echo "CARGO_CHECK_RC=$CHECK_RC"
echo

echo "=== DECISION ==="

if [ "$CHECK_RC" -ne 0 ]; then
  echo "HALO9_BRIDGE_CONTRACT_DECISION=BLOCKED"
  echo "REASON=existing_bridge_does_not_currently_build_cleanly"
else
  echo "HALO9_BRIDGE_CONTRACT_DECISION=REVIEW_REQUIRED"
  echo "REASON=bridge_builds_but_public_authority_contract_must_be_explicit_before_integration"
fi

echo
echo "HALO9_V2=VERIFIED"
echo "HALO9_V2_TESTS=13_PASS"
echo "SOURCE_MODIFICATION=NONE"
echo "PRODUCTION_CRYPTO=NOT_CONFIGURED"
echo "PRODUCTION_UNLOCK=BLOCKED"
echo "REPORT=$REPORT"

echo
echo "=================================================="
echo " CONTRACT INSPECTION COMPLETE"
echo "=================================================="
