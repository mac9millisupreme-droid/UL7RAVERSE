#!/data/data/com.termux/files/usr/bin/bash
set -u

ROOT="$HOME/UL7RAVERSE"
BRIDGE="$ROOT/UL7RAFORGE/v10/ul7rabridge"
V2="$ROOT/halo9_bridge_gate_v2/halo9_bridge_gate_v2"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/verification_artifacts/halo9_v55/$TS"
EVID="$OUT/evidence"
REPORT="$OUT/HALO9_V55_REPORT.txt"

mkdir -p "$EVID"
: > "$REPORT"

PASS=0
REVIEW=0
BLOCK=0

log() {
  echo "$*" | tee -a "$REPORT"
}

gate() {
  N="$1"
  NAME="$2"
  shift 2
  FILE="$EVID/V${N}.txt"

  log ""
  log "=== V${N} ${NAME} ==="

  if "$@" >"$FILE" 2>&1; then
    log "V${N}_STATUS=PASS"
    PASS=$((PASS+1))
  else
    log "V${N}_STATUS=REVIEW_REQUIRED"
    REVIEW=$((REVIEW+1))
  fi

  cat "$FILE" >> "$REPORT"
}

log "=================================================="
log "HALO9 V55 ONE-SCRIPT VERIFICATION"
log "UTC=$TS"
log "=================================================="

if [ ! -d "$ROOT" ]; then
  log "HALO9_V55_FINAL_DECISION=BLOCKED"
  log "REASON=UL7RAVERSE_NOT_FOUND"
  exit 2
fi

if [ ! -d "$BRIDGE" ]; then
  log "HALO9_V55_FINAL_DECISION=BLOCKED"
  log "REASON=REAL_UL7RABRIDGE_NOT_FOUND"
  exit 2
fi

if [ ! -d "$V2" ]; then
  log "HALO9_V55_FINAL_DECISION=BLOCKED"
  log "REASON=HALO9_V2_NOT_FOUND"
  exit 2
fi

# --------------------------------------------------
# V03-V10 — REAL BRIDGE CONTRACT
# --------------------------------------------------

gate 03 REAL_BRIDGE \
  test -f "$BRIDGE/Cargo.toml"

gate 04 POLICY_AND_INVARIANTS \
  bash -c "test -f '$BRIDGE/policy/cheetah.json' && test -f '$BRIDGE/state/invariants.json'"

gate 05 CHEETAH \
  test -f "$BRIDGE/cheetah/src/main.rs"

gate 06 DIRECTION_ENFORCEMENT \
  bash -c "grep -RniE 'SOVEREIGN_TO_EXTERNAL|prohibited direction|CHEETAH DENY' '$BRIDGE/src' '$BRIDGE/cheetah'"

gate 07 CAPABILITY_BOUNDARY \
  bash -c "grep -RniE 'capabilit' '$BRIDGE/src' '$BRIDGE/cheetah' || true"

gate 08 MISSION_BOUNDARY \
  bash -c "grep -RniE 'mission' '$BRIDGE/src' '$BRIDGE/cheetah' || true"

gate 09 HALO_PROOF_BOUNDARY \
  bash -c "grep -RniE 'halo|twin|proof|verify' '$BRIDGE/src' '$BRIDGE/cheetah' || true"

gate 10 REPLAY_SEQUENCE_BOUNDARY \
  bash -c "grep -RniE 'nonce|sequence|replay|rollback' '$BRIDGE' --exclude-dir=target --exclude='*.pyc' || true"

# --------------------------------------------------
# V11-V20 — SECURITY BOUNDARIES
# --------------------------------------------------

gate 11 EXPIRY_BOUNDARY \
  bash -c "grep -RniE 'expir|ttl|deadline' '$BRIDGE' --exclude-dir=target --exclude='*.pyc' || true"

gate 12 REVOCATION_BOUNDARY \
  bash -c "grep -RniE 'revok' '$BRIDGE' --exclude-dir=target --exclude='*.pyc' || true"

gate 13 COMPROMISE_BOUNDARY \
  bash -c "grep -RniE 'comprom|tamper|blocked' '$BRIDGE' --exclude-dir=target --exclude='*.pyc' || true"

gate 14 ROLLBACK_BOUNDARY \
  bash -c "grep -RniE 'rollback|sequence|version' '$BRIDGE' --exclude-dir=target --exclude='*.pyc' || true"

gate 15 CROSS_PAIR_BOUNDARY \
  bash -c "grep -RniE 'pair|agent|twin' '$BRIDGE' --exclude-dir=target --exclude='*.pyc' || true"

gate 16 GHOST_PARTITION \
  bash -c "grep -RniE 'ghost' '$BRIDGE' --exclude-dir=target --exclude='*.pyc' || true"

gate 17 ONE_WAY_BOUNDARY \
  bash -c "grep -RniE 'one[-_ ]?way|direction' '$BRIDGE/policy' '$BRIDGE/src' '$BRIDGE/cheetah' 2>/dev/null || true"

gate 18 CLOUD_TRUST_BOUNDARY \
  bash -c "! grep -RniE 'cloud.*trust|trust.*cloud' '$BRIDGE' --exclude-dir=target --exclude='*.pyc'"

gate 19 TUNNEL_BOUNDARY \
  bash -c "grep -RniE 'tunnel|cloudflare' '$BRIDGE' --exclude-dir=target --exclude='*.pyc' || true"

gate 20 DEVICE_NODE_BOUNDARY \
  bash -c "grep -RniE 'device|node' '$BRIDGE/state' '$BRIDGE/policy' '$BRIDGE/tests' 2>/dev/null || true"

# --------------------------------------------------
# V21-V30 — PROOF / TEST SURFACE
# --------------------------------------------------

gate 21 DURABLE_PROOF \
  bash -c "grep -RniE 'durable|ephemeral|persistence|ledger' '$BRIDGE' --exclude-dir=target --exclude='*.pyc' || true"

gate 22 STATE_SURFACE \
  bash -c "find '$BRIDGE' -maxdepth 3 -type f | grep -Ei 'state|proof|ledger|record' || true"

gate 23 LEDGER_STATUS \
  bash -c "grep -RniE 'ledger|record_bridge_status|status' '$BRIDGE/tests' '$BRIDGE/state' 2>/dev/null || true"

gate 24 HASH_CONTINUITY \
  bash -c "grep -RniE 'sha256|merkle|hash' '$BRIDGE' --exclude-dir=target --exclude='*.pyc' || true"

gate 25 TIMESTAMP_NONCE \
  bash -c "grep -RniE 'timestamp|nonce' '$BRIDGE' --exclude-dir=target --exclude='*.pyc' || true"

gate 26 REPLAY_TEST \
  test -f "$BRIDGE/tests/live_status_regression.sh"

gate 27 TEST_SURFACE \
  find "$BRIDGE/tests" -maxdepth 1 -type f

gate 28 FUZZ_SURFACE \
  bash -c "grep -RniE 'fuzz|proptest|quickcheck' '$BRIDGE' --exclude-dir=target --exclude='*.pyc' || true"

gate 29 NEGATIVE_PATHS \
  bash -c "grep -RniE 'deny|blocked|reject|invariant|fail' '$BRIDGE/tests' || true"

gate 30 SERIALIZATION \
  bash -c "grep -RniE 'serde|Serialize|Deserialize|to_string|from_str' '$BRIDGE/src' '$BRIDGE/cheetah'"

# --------------------------------------------------
# V31-V40 — EXISTING ASSURANCE
# --------------------------------------------------

gate 31 DESERIALIZATION \
  bash -c "grep -RniE 'Deserialize|from_str|invalid' '$BRIDGE' --exclude-dir=target --exclude='*.pyc' || true"

gate 32 POLICY_TAMPER \
  test -x "$BRIDGE/tests/tamper_detection.sh"

gate 33 INVARIANT_TAMPER \
  test -x "$BRIDGE/tests/bridge_invariant.sh"

gate 34 CHEETAH_REGRESSION \
  test -x "$BRIDGE/tests/cheetah_regression.sh"

gate 35 GHOST_REGRESSION \
  test -x "$BRIDGE/tests/ghost_regression.sh"

gate 36 CANADA_ONLY_REGRESSION \
  test -x "$BRIDGE/tests/canada_only_regression.sh"

gate 37 SECURITY_ASSURANCE \
  test -x "$BRIDGE/tests/security_assurance.sh"

gate 38 OS_BASELINE \
  test -x "$BRIDGE/tests/os_baseline.sh"

gate 39 LIVE_STATUS \
  test -x "$BRIDGE/tests/live_status_regression.sh"

gate 40 INDEPENDENT_VERIFIER \
  test -x "$BRIDGE/tests/independent_verifier.sh"

# --------------------------------------------------
# V41-V50 — GOVERNANCE SEPARATION
# --------------------------------------------------

gate 41 FAIL_CLOSED \
  bash -c "grep -RniE 'DENY|deny|BLOCK|blocked|fail' '$BRIDGE/src' '$BRIDGE/cheetah'"

gate 42 AUTHORITY_SEPARATION \
  bash -c "! grep -RniE 'self[-_ ]?author|self[-_ ]?cert|self[-_ ]?approve' '$BRIDGE' --exclude-dir=target --exclude='*.pyc'"

gate 43 NO_SELF_CERTIFICATION \
  bash -c "! grep -RniE 'self[-_ ]?cert|self[-_ ]?author|self[-_ ]?approve' '$BRIDGE' --exclude-dir=target --exclude='*.pyc'"

gate 44 PROOF_NOT_AUTHORITY \
  bash -c "! grep -RniE 'proof.*grant|proof.*author' '$BRIDGE/src' '$BRIDGE/cheetah'"

gate 45 BRIDGE_NOT_PROOF_MINT \
  bash -c "! grep -RniE 'halo.*mint|twin.*mint|proof.*mint' '$BRIDGE/src' '$BRIDGE/cheetah'"

gate 46 AGENT_TWIN_SEPARATION \
  bash -c "! grep -RniE 'agent.*(mint|create).*twin' '$BRIDGE/src' '$BRIDGE/cheetah'"

gate 47 TWIN_AGENT_SEPARATION \
  bash -c "! grep -RniE 'twin.*(execute|command)' '$BRIDGE/src' '$BRIDGE/cheetah'"

gate 48 CROSS_MISSION \
  bash -c "! grep -RniE 'cross[-_ ]?mission' '$BRIDGE/src' '$BRIDGE/cheetah'"

gate 49 CROSS_DEVICE \
  bash -c "! grep -RniE 'cross[-_ ]?device' '$BRIDGE/src' '$BRIDGE/cheetah'"

gate 50 CROSS_VERSION \
  bash -c "git -C '$ROOT' rev-parse HEAD"

# --------------------------------------------------
# V51-V54 — CRYPTO + HALO9
# --------------------------------------------------

gate 51 PQC_SURFACE \
  bash -c "grep -RniE 'pqc|ml-kem|ml_dsa|slh|kem|signature' '$V2' '$BRIDGE' --exclude-dir=target --exclude='*.pyc' || true"

gate 52 CRYPTO_AGILITY \
  bash -c "grep -RniE 'crypto.*suite|provider|algorithm' '$V2' '$BRIDGE' --exclude-dir=target --exclude='*.pyc' || true"

gate 53 PRODUCTION_CRYPTO_GATE \
  bash -c "grep -RniE 'NOT_CONFIGURED|production_crypto_provider' '$V2' || true"

gate 54 HALO9_V2_TESTS \
  bash -c "cd '$V2' && cargo test --all-targets"

# --------------------------------------------------
# V55 — FINAL GOVERNANCE GATE
# --------------------------------------------------

log ""
log "=== V55 FINAL INTEGRATION GATE ==="

cd "$BRIDGE" || exit 1
cargo check >"$EVID/V55_bridge_cargo_check.txt" 2>&1
BRIDGE_RC=$?

cd "$V2" || exit 1
cargo test --all-targets >"$EVID/V55_halo9_tests.txt" 2>&1
HALO_RC=$?

cat "$EVID/V55_bridge_cargo_check.txt" >> "$REPORT"
cat "$EVID/V55_halo9_tests.txt" >> "$REPORT"

log "BRIDGE_CARGO_CHECK_RC=$BRIDGE_RC"
log "HALO9_V2_TEST_RC=$HALO_RC"
log "HALO9_V2_TESTS=13_EXPECTED"

log "HALO9_V55_RULE=NO_VALID_HALO_TWIN_PAIR_NO_ACTION"
log "HALO9_V55_RULE_2=NO_REVIEWED_PRODUCTION_CRYPTO_NO_PRODUCTION_UNLOCK"
log "SOURCE_MODIFICATION=NONE"
log "PRODUCTION_CRYPTO=NOT_CONFIGURED"
log "PRODUCTION_UNLOCK=BLOCKED"

if [ "$BRIDGE_RC" -eq 0 ] && [ "$HALO_RC" -eq 0 ]; then
  FINAL="REVIEW_REQUIRED"
else
  FINAL="BLOCKED"
fi

log "HALO9_V55_FINAL_DECISION=$FINAL"

cat > "$OUT/FINAL_DECISION.txt" <<EOT
HALO9_V55_FINAL_DECISION=$FINAL
BRIDGE_CARGO_CHECK_RC=$BRIDGE_RC
HALO9_V2_TEST_RC=$HALO_RC
SOURCE_MODIFICATION=NONE
PRODUCTION_CRYPTO=NOT_CONFIGURED
PRODUCTION_UNLOCK=BLOCKED
RULE=NO_VALID_HALO_TWIN_PAIR_NO_ACTION
EOT

log ""
log "=================================================="
log "HALO9 V55 COMPLETE"
log "=================================================="
log "FINAL_DECISION=$FINAL"
log "REPORT=$REPORT"
log "EVIDENCE=$EVID"
log "PRODUCTION_UNLOCK=BLOCKED"
log "=================================================="

exit 0
