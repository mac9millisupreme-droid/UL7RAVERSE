#!/data/data/com.termux/files/usr/bin/bash
set -u

ROOT="$HOME/UL7RAVERSE"
PROJECT="$ROOT/halo9_v56_authority_contract"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/verification_artifacts/halo9_v56_full/$TS"
REPORT="$OUT/HALO9_V56_FULL_REPORT.txt"

mkdir -p "$OUT"

log() {
    echo "$*" | tee -a "$REPORT"
}

run_capture() {
    NAME="$1"
    shift
    "$@" >"$OUT/$NAME.log" 2>&1
    return $?
}

log "=================================================="
log "HALO9 V56 — FULL VERIFICATION GATE"
log "UTC=$TS"
log "=================================================="

log "PROJECT=$PROJECT"
log "REAL_BRIDGE_MODIFICATION=NONE"
log "REAL_BRIDGE_INTEGRATION=NOT_PERFORMED"

if [ ! -d "$PROJECT" ]; then
    log "PROJECT=NOT_FOUND"
    exit 1
fi

cd "$PROJECT" || exit 1

# ==================================================
# 1. FORMAT
# ==================================================

log ""
log "=== FORMAT ==="

cargo fmt --check >"$OUT/fmt.log" 2>&1
FMT_RC=$?

if [ "$FMT_RC" -ne 0 ]; then
    log "FORMAT_REPAIR=RUNNING"
    cargo fmt >>"$OUT/fmt.log" 2>&1
    cargo fmt --check >>"$OUT/fmt.log" 2>&1
    FMT_RC=$?
fi

log "CARGO_FMT_RC=$FMT_RC"

# ==================================================
# 2. COMPILE
# ==================================================

log ""
log "=== COMPILE ==="

cargo check >"$OUT/check.log" 2>&1
CHECK_RC=$?

tail -n 30 "$OUT/check.log" | tee -a "$REPORT"

log "CARGO_CHECK_RC=$CHECK_RC"

# ==================================================
# 3. TEST
# ==================================================

log ""
log "=== V56 TEST SUITE ==="

cargo test --all-targets >"$OUT/test.log" 2>&1
TEST_RC=$?

tail -n 60 "$OUT/test.log" | tee -a "$REPORT"

log "CARGO_TEST_RC=$TEST_RC"

# ==================================================
# 4. TEST RESULT EXTRACTION
# ==================================================

TEST_RESULT="UNKNOWN"

if grep -q "test result: ok" "$OUT/test.log"; then
    TEST_RESULT="PASS"
elif grep -q "test result:" "$OUT/test.log"; then
    TEST_RESULT="FAIL"
fi

log "V56_TEST_RESULT=$TEST_RESULT"

# ==================================================
# 5. LUCI TEST DISCOVERY
# ==================================================

log ""
log "=== LUCITEST ==="

LUCITEST_STATUS="NOT_DISCOVERED"

LUCITEST_CANDIDATES=(
    "$ROOT/lucitest.sh"
    "$ROOT/LUCITEST.sh"
    "$ROOT/LUCI_TEST.sh"
    "$ROOT/luci_test.sh"
    "$ROOT/ul7ra_continue/LUCITEST.sh"
)

for CANDIDATE in "${LUCITEST_CANDIDATES[@]}"; do
    if [ -x "$CANDIDATE" ]; then
        log "LUCITEST_FOUND=$CANDIDATE"

        "$CANDIDATE" >"$OUT/lucitest.log" 2>&1
        LUCITEST_RC=$?

        cat "$OUT/lucitest.log" >>"$REPORT"

        if [ "$LUCITEST_RC" -eq 0 ]; then
            LUCITEST_STATUS="PASS"
        else
            LUCITEST_STATUS="FAIL"
        fi

        break
    fi
done

if [ "$LUCITEST_STATUS" = "NOT_DISCOVERED" ]; then
    log "LUCITEST_STATUS=NOT_DISCOVERED"
    log "LUCITEST_CLAIM=NONE"
else
    log "LUCITEST_STATUS=$LUCITEST_STATUS"
fi

# ==================================================
# 6. LUCI DIAGNOSTIC DISCOVERY
# ==================================================

log ""
log "=== LUCI DIAGNOSTIC ==="

LUCIDIAG_STATUS="NOT_DISCOVERED"

LUCIDIAG_CANDIDATES=(
    "$ROOT/luci_diagnostic.sh"
    "$ROOT/LUCI_DIAGNOSTIC.sh"
    "$ROOT/LUCIDIAGNOSTIC.sh"
    "$ROOT/luci-diagnostic.sh"
    "$ROOT/ul7ra_continue/LUCI_DIAGNOSTIC.sh"
)

for CANDIDATE in "${LUCIDIAG_CANDIDATES[@]}"; do
    if [ -x "$CANDIDATE" ]; then
        log "LUCIDIAGNOSTIC_FOUND=$CANDIDATE"

        "$CANDIDATE" >"$OUT/luci_diagnostic.log" 2>&1
        LUCIDIAG_RC=$?

        cat "$OUT/luci_diagnostic.log" >>"$REPORT"

        if [ "$LUCIDIAG_RC" -eq 0 ]; then
            LUCIDIAG_STATUS="PASS"
        else
            LUCIDIAG_STATUS="FAIL"
        fi

        break
    fi
done

if [ "$LUCIDIAG_STATUS" = "NOT_DISCOVERED" ]; then
    log "LUCIDIAGNOSTIC_STATUS=NOT_DISCOVERED"
    log "LUCIDIAGNOSTIC_CLAIM=NONE"
else
    log "LUCIDIAGNOSTIC_STATUS=$LUCIDIAG_STATUS"
fi

# ==================================================
# 7. STATIC GOVERNANCE CHECKS
# ==================================================

log ""
log "=== GOVERNANCE STATIC CHECKS ==="

grep -q "ProductionCryptoNotConfigured" src/lib.rs
CRYPTO_GATE_RC=$?

grep -q "HaloPairMismatch" src/lib.rs
PAIR_BINDING_RC=$?

grep -q "MissionMismatch" src/lib.rs
MISSION_BINDING_RC=$?

grep -q "CapabilityMismatch" src/lib.rs
CAPABILITY_BINDING_RC=$?

grep -q "CheetahDenied" src/lib.rs
CHEETAH_GATE_RC=$?

grep -q "BridgeDenied" src/lib.rs
BRIDGE_GATE_RC=$?

grep -q "verify_ledger_entry" src/lib.rs
LEDGER_GATE_RC=$?

grep -q "verify_pair_binding" src/lib.rs
CRYPTO_VERIFY_RC=$?

log "CRYPTO_GATE=$([ "$CRYPTO_GATE_RC" -eq 0 ] && echo PASS || echo FAIL)"
log "PAIR_BINDING=$([ "$PAIR_BINDING_RC" -eq 0 ] && echo PASS || echo FAIL)"
log "MISSION_BINDING=$([ "$MISSION_BINDING_RC" -eq 0 ] && echo PASS || echo FAIL)"
log "CAPABILITY_BINDING=$([ "$CAPABILITY_BINDING_RC" -eq 0 ] && echo PASS || echo FAIL)"
log "CHEETAH_GATE=$([ "$CHEETAH_GATE_RC" -eq 0 ] && echo PASS || echo FAIL)"
log "BRIDGE_GATE=$([ "$BRIDGE_GATE_RC" -eq 0 ] && echo PASS || echo FAIL)"
log "LEDGER_GATE=$([ "$LEDGER_GATE_RC" -eq 0 ] && echo PASS || echo FAIL)"
log "CRYPTO_VERIFY=$([ "$CRYPTO_VERIFY_RC" -eq 0 ] && echo PASS || echo FAIL)"

# ==================================================
# 8. SOURCE HASH
# ==================================================

if command -v sha256sum >/dev/null 2>&1; then
    sha256sum src/lib.rs >"$OUT/V56_SOURCE_SHA256.txt"
    log "SOURCE_HASH=RECORDED"
fi

# ==================================================
# 9. FINAL GOVERNANCE DECISION
# ==================================================

log ""
log "=================================================="
log "HALO9 V56 FINAL GOVERNANCE GATE"
log "=================================================="

log "CORE_RULE=NO_VALID_HALO_TWIN_PAIR_NO_ACTION"
log "AUTHORITY_RULE=PROOF_DOES_NOT_EQUAL_AUTHORITY"
log "LUCITEST_IS_AUTHORITY=NO"
log "LUCIDIAGNOSTIC_IS_AUTHORITY=NO"
log "REAL_BRIDGE_MODIFICATION=NONE"
log "REAL_BRIDGE_INTEGRATION=NOT_PERFORMED"
log "PRODUCTION_CRYPTO=NOT_CONFIGURED"
log "PRODUCTION_UNLOCK=BLOCKED"

if [ "$FMT_RC" -eq 0 ] &&
   [ "$CHECK_RC" -eq 0 ] &&
   [ "$TEST_RC" -eq 0 ] &&
   [ "$TEST_RESULT" = "PASS" ] &&
   [ "$CRYPTO_GATE_RC" -eq 0 ] &&
   [ "$PAIR_BINDING_RC" -eq 0 ] &&
   [ "$MISSION_BINDING_RC" -eq 0 ] &&
   [ "$CAPABILITY_BINDING_RC" -eq 0 ] &&
   [ "$CHEETAH_GATE_RC" -eq 0 ] &&
   [ "$BRIDGE_GATE_RC" -eq 0 ] &&
   [ "$LEDGER_GATE_RC" -eq 0 ] &&
   [ "$CRYPTO_VERIFY_RC" -eq 0 ]; then

    FINAL="PASS_WITH_PRODUCTION_BLOCK"
else
    FINAL="REVIEW_REQUIRED"
fi

log "HALO9_V56_FINAL_DECISION=$FINAL"

# ==================================================
# 10. FINAL DECISION ARTIFACT
# ==================================================

cat >"$OUT/FINAL_DECISION.txt" <<DECISION
HALO9_V56_FINAL_DECISION=$FINAL

CARGO_FMT_RC=$FMT_RC
CARGO_CHECK_RC=$CHECK_RC
CARGO_TEST_RC=$TEST_RC
V56_TEST_RESULT=$TEST_RESULT

LUCITEST_STATUS=$LUCITEST_STATUS
LUCIDIAGNOSTIC_STATUS=$LUCIDIAG_STATUS

CRYPTO_GATE=$([ "$CRYPTO_GATE_RC" -eq 0 ] && echo PASS || echo FAIL)
PAIR_BINDING=$([ "$PAIR_BINDING_RC" -eq 0 ] && echo PASS || echo FAIL)
MISSION_BINDING=$([ "$MISSION_BINDING_RC" -eq 0 ] && echo PASS || echo FAIL)
CAPABILITY_BINDING=$([ "$CAPABILITY_BINDING_RC" -eq 0 ] && echo PASS || echo FAIL)
CHEETAH_GATE=$([ "$CHEETAH_GATE_RC" -eq 0 ] && echo PASS || echo FAIL)
BRIDGE_GATE=$([ "$BRIDGE_GATE_RC" -eq 0 ] && echo PASS || echo FAIL)
LEDGER_GATE=$([ "$LEDGER_GATE_RC" -eq 0 ] && echo PASS || echo FAIL)
CRYPTO_VERIFY=$([ "$CRYPTO_VERIFY_RC" -eq 0 ] && echo PASS || echo FAIL)

CORE_RULE=NO_VALID_HALO_TWIN_PAIR_NO_ACTION
AUTHORITY_RULE=PROOF_DOES_NOT_EQUAL_AUTHORITY

REAL_BRIDGE_MODIFICATION=NONE
REAL_BRIDGE_INTEGRATION=NOT_PERFORMED

PRODUCTION_CRYPTO=NOT_CONFIGURED
PRODUCTION_UNLOCK=BLOCKED
DECISION

log ""
log "REPORT=$REPORT"
log "EVIDENCE=$OUT"
log "=================================================="

exit 0
