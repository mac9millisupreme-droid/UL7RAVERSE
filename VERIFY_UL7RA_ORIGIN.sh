#!/data/data/com.termux/files/usr/bin/bash
set -u

BASE="http://127.0.0.1:8787"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$HOME/UL7RAVERSE/verification_artifacts/origin_runtime/VERIFY_$TS"

mkdir -p "$OUT"

echo "=== UL7RA ORIGIN GOVERNED VERIFICATION ==="
echo "BASE=$BASE"
echo "EVIDENCE=$OUT"
echo

check() {
    NAME="$1"
    PATH="$2"

    echo "=== $NAME : $PATH ==="

    HTTP="$(curl -sS -o "$OUT/${NAME}.json" -w '%{http_code}' \
        --max-time 5 "$BASE$PATH" 2>/dev/null || echo 000)"

    echo "HTTP=$HTTP"

    if [ -f "$OUT/${NAME}.json" ]; then
        cat "$OUT/${NAME}.json"
        echo
    fi

    echo "$NAME|$PATH|HTTP=$HTTP" >> "$OUT/RESULTS.tsv"
}

check HEALTH /health
check SELFTEST /selftest
check INTEGRITY /integrity
check STATE /state
check ROOT /

echo
echo "=== PROCESS ==="

PID="$(pgrep -f 'UL7RA_V99_LITE_TERMUX' | head -1 || true)"

if [ -n "$PID" ]; then
    echo "PID=$PID"
    echo "PROCESS=RUNNING"
else
    echo "PROCESS=NOT_FOUND"
fi

echo
echo "=== RESULTS ==="
cat "$OUT/RESULTS.tsv"

HEALTH_OK=0
SELFTEST_OK=0
INTEGRITY_OK=0
PROCESS_OK=0

grep -q '"ok"[[:space:]]*:[[:space:]]*true' "$OUT/HEALTH.json" 2>/dev/null && HEALTH_OK=1
grep -qi 'pass' "$OUT/SELFTEST.json" 2>/dev/null && SELFTEST_OK=1
grep -qi 'valid' "$OUT/INTEGRITY.json" 2>/dev/null && INTEGRITY_OK=1
[ -n "$PID" ] && PROCESS_OK=1

echo
echo "HEALTH_OK=$HEALTH_OK"
echo "SELFTEST_OK=$SELFTEST_OK"
echo "INTEGRITY_OK=$INTEGRITY_OK"
echo "PROCESS_OK=$PROCESS_OK"

if [ "$HEALTH_OK" -eq 1 ] &&
   [ "$SELFTEST_OK" -eq 1 ] &&
   [ "$INTEGRITY_OK" -eq 1 ] &&
   [ "$PROCESS_OK" -eq 1 ]; then
    FINAL="PASS_WITH_ENVIRONMENT_BLOCK"
else
    FINAL="BLOCKED"
fi

cat > "$OUT/FINAL_DECISION.md" <<EOF
# UL7RA Origin Governed Verification

BASE: $BASE
TIMESTAMP: $TS

HEALTH_OK: $HEALTH_OK
SELFTEST_OK: $SELFTEST_OK
INTEGRITY_OK: $INTEGRITY_OK
PROCESS_OK: $PROCESS_OK

STATE_AND_ROOT_ARE_OBSERVATIONAL_ONLY.

Governance:
UNVERIFIED_NEVER_PASS
UNKNOWN_REMAINS_UNKNOWN
NO_PROOF_NO_TRUSTED_ACTION
NO_SELF_CERTIFICATION
FAIL_CLOSED

FINAL_DECISION: $FINAL
EOF

echo
cat "$OUT/FINAL_DECISION.md"
echo
echo "EVIDENCE=$OUT"
