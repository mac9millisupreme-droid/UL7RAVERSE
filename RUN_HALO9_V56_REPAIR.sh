#!/data/data/com.termux/files/usr/bin/bash
set -u

ROOT="$HOME/UL7RAVERSE"
PROJECT="$ROOT/halo9_v56_authority_contract"
SRC="$PROJECT/src/lib.rs"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/verification_artifacts/halo9_v56_repair/$TS"
REPORT="$OUT/HALO9_V56_REPAIR_REPORT.txt"

mkdir -p "$OUT"

log() {
    echo "$*" | tee -a "$REPORT"
}

log "=================================================="
log "HALO9 V56 — MINIMAL REPAIR + VERIFY"
log "UTC=$TS"
log "=================================================="

if [ ! -f "$SRC" ]; then
    log "V56_SOURCE=NOT_FOUND"
    exit 1
fi

log "PROJECT=$PROJECT"
log "SOURCE=$SRC"

# --------------------------------------------------
# SAFETY: REAL BRIDGE MUST REMAIN UNTOUCHED
# --------------------------------------------------

if [ -d "$ROOT/UL7RAFORGE/v10/ul7rabridge" ]; then
    log "REAL_UL7RABRIDGE=FOUND"
else
    log "REAL_UL7RABRIDGE=NOT_FOUND"
fi

log "REAL_BRIDGE_MODIFICATION=NONE"
log "REAL_BRIDGE_INTEGRATION=NOT_PERFORMED"

# --------------------------------------------------
# MINIMAL RUST REPAIR
#
# AuthorityContract contains borrowed trait objects.
# It must not derive Debug/Clone.
# --------------------------------------------------

if grep -q '^#\[derive(Debug, Clone)\]$' "$SRC"; then
    sed -i '/^#\[derive(Debug, Clone)\]$/d' "$SRC"
    log "REPAIR=REMOVED_AUTHORITY_CONTRACT_DEBUG_CLONE"
else
    log "REPAIR=NOT_REQUIRED_OR_ALREADY_APPLIED"
fi

# --------------------------------------------------
# VERIFY THE REPAIR
# --------------------------------------------------

if grep -n "pub struct AuthorityContract" "$SRC" >/dev/null 2>&1; then
    log "AUTHORITY_CONTRACT=FOUND"
else
    log "AUTHORITY_CONTRACT=NOT_FOUND"
    exit 1
fi

# --------------------------------------------------
# FORMAT
# --------------------------------------------------

log ""
log "=== CARGO FMT ==="

cargo fmt --check >>"$REPORT" 2>&1
FMT_RC=$?

if [ "$FMT_RC" -ne 0 ]; then
    log "FORMAT_REPAIR=RUNNING"
    cargo fmt >>"$REPORT" 2>&1
    cargo fmt --check >>"$REPORT" 2>&1
    FMT_RC=$?
fi

log "CARGO_FMT_RC=$FMT_RC"

# --------------------------------------------------
# CHECK
# --------------------------------------------------

log ""
log "=== CARGO CHECK ==="

cargo check >>"$REPORT" 2>&1
CHECK_RC=$?

log "CARGO_CHECK_RC=$CHECK_RC"

# --------------------------------------------------
# TEST
# --------------------------------------------------

log ""
log "=== CARGO TEST ==="

cargo test --all-targets >>"$REPORT" 2>&1
TEST_RC=$?

log "CARGO_TEST_RC=$TEST_RC"

# --------------------------------------------------
# EXTRACT TEST SUMMARY
# --------------------------------------------------

log ""
log "=== TEST SUMMARY ==="

grep -E \
'passed|failed|test result|running [0-9]+ tests' \
"$REPORT" | tail -n 20 | tee -a "$REPORT" || true

# --------------------------------------------------
# GOVERNANCE GATE
# --------------------------------------------------

log ""
log "=== V56 GOVERNANCE GATE ==="

log "CORE_RULE=NO_VALID_HALO_TWIN_PAIR_NO_ACTION"
log "AUTHORITY_RULE=PROOF_DOES_NOT_EQUAL_AUTHORITY"
log "REAL_BRIDGE_MODIFICATION=NONE"
log "REAL_BRIDGE_INTEGRATION=NOT_PERFORMED"
log "PRODUCTION_CRYPTO=NOT_CONFIGURED"
log "PRODUCTION_UNLOCK=BLOCKED"

if [ "$FMT_RC" -eq 0 ] &&
   [ "$CHECK_RC" -eq 0 ] &&
   [ "$TEST_RC" -eq 0 ]; then

    FINAL="PASS_WITH_PRODUCTION_BLOCK"
else
    FINAL="BLOCKED"
fi

log "HALO9_V56_FINAL_DECISION=$FINAL"

# --------------------------------------------------
# SOURCE HASH
# --------------------------------------------------

if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$SRC" > "$OUT/V56_SOURCE_SHA256.txt"
    log "SOURCE_HASH=RECORDED"
fi

# --------------------------------------------------
# FINAL DECISION ARTIFACT
# --------------------------------------------------

cat > "$OUT/FINAL_DECISION.txt" <<DECISION
HALO9_V56_FINAL_DECISION=$FINAL
CARGO_FMT_RC=$FMT_RC
CARGO_CHECK_RC=$CHECK_RC
CARGO_TEST_RC=$TEST_RC
CORE_RULE=NO_VALID_HALO_TWIN_PAIR_NO_ACTION
AUTHORITY_RULE=PROOF_DOES_NOT_EQUAL_AUTHORITY
REAL_BRIDGE_MODIFICATION=NONE
REAL_BRIDGE_INTEGRATION=NOT_PERFORMED
PRODUCTION_CRYPTO=NOT_CONFIGURED
PRODUCTION_UNLOCK=BLOCKED
DECISION

log ""
log "=================================================="
log "HALO9 V56 REPAIR COMPLETE"
log "=================================================="
log "FINAL_DECISION=$FINAL"
log "REPORT=$REPORT"
log "EVIDENCE=$OUT"
log "PRODUCTION_UNLOCK=BLOCKED"
log "=================================================="

exit 0
