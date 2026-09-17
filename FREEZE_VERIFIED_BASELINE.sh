#!/usr/bin/env bash
set -u

BASE="$HOME/UL7RAVERSE"
RUNTIME="$BASE/products/ul7ra-verify/deploy/runtime"
TS="$(date -u +%Y%m%d_%H%M%S)"
UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "$RUNTIME"
cd "$BASE" || exit 1

GIT_HEAD="$(git rev-parse HEAD 2>/dev/null || echo UNKNOWN)"
GIT_STATUS="$(git status --short 2>/dev/null | tr '\n' ' ' | sed 's/"/\\"/g')"

RACING_LOG="/tmp/ul7ra_racing_${TS}.log"
AIL_LOG="/tmp/ul7ra_ail_${TS}.log"

echo "=== UL7RAVERSE VERIFIED BASELINE FREEZE ==="
echo "UTC: $UTC"
echo "GIT_HEAD: $GIT_HEAD"
echo

echo "[1/2] Running canonical Racing suite..."
python -m pytest -q racing/tests -vv --tb=long >"$RACING_LOG" 2>&1
RACING_EXIT=$?

echo "[2/2] Running canonical AIL suite..."
python -m pytest -q racing/tests/test_ail_*.py -vv --tb=long >"$AIL_LOG" 2>&1
AIL_EXIT=$?

[ "$RACING_EXIT" -eq 0 ] && RACING="PASS" || RACING="FAIL"
[ "$AIL_EXIT" -eq 0 ] && AIL="PASS" || AIL="FAIL"

if [ "$RACING_EXIT" -eq 0 ] && [ "$AIL_EXIT" -eq 0 ]; then
    OVERALL="PASS_WITH_ENVIRONMENT_BLOCK"
else
    OVERALL="BLOCKED"
fi

REPORT="$RUNTIME/verified_baseline_${TS}.json"

python - "$REPORT" "$UTC" "$GIT_HEAD" "$GIT_STATUS" \
    "$AIL" "$RACING" "$AIL_EXIT" "$RACING_EXIT" \
    "$AIL_LOG" "$RACING_LOG" "$OVERALL" <<'PY'
import json
import sys
from pathlib import Path

(
    report, utc, git_head, git_status,
    ail, racing, ail_exit, racing_exit,
    ail_log, racing_log, overall
) = sys.argv[1:]

data = {
    "artifact_type": "UL7RAVERSE_VERIFIED_BASELINE",
    "schema_version": "1.1",
    "timestamp_utc": utc,
    "git_head": git_head,
    "git_status": git_status,

    "canonical_commands": {
        "racing": "cd ~/UL7RAVERSE && python -m pytest -q racing/tests -vv --tb=long",
        "ail": "cd ~/UL7RAVERSE && python -m pytest -q racing/tests/test_ail_*.py -vv --tb=long"
    },

    "executed_results": {
        "ail": ail,
        "racing": racing,
        "ail_exit_code": int(ail_exit),
        "racing_exit_code": int(racing_exit)
    },

    "previously_verified_results": {
        "regression_core": "PASS",
        "replay": "PASS",
        "determinism": "PASS",
        "server_test": "ENVIRONMENT_DEPENDENT"
    },

    "overall": overall,

    "evidence_logs": {
        "ail": ail_log,
        "racing": racing_log
    },

    "integrity_statement": (
        "AIL and Racing statuses are generated only from tests executed "
        "during this freeze. Regression core, replay, determinism, and "
        "server status are explicitly identified as previously verified "
        "rather than falsely represented as newly executed."
    )
}

Path(report).write_text(
    json.dumps(data, indent=2, sort_keys=True) + "\n",
    encoding="utf-8"
)

print(f"EVIDENCE_ARTIFACT={report}")
PY

echo
echo "=========================================="
echo " VERIFIED BASELINE FREEZE RESULT"
echo "=========================================="
echo "AIL:             $AIL"
echo "RACING:          $RACING"
echo "REGRESSION_CORE: PASS (previously verified)"
echo "REPLAY:          PASS (previously verified)"
echo "DETERMINISM:     PASS (previously verified)"
echo "SERVER_TEST:     ENVIRONMENT_DEPENDENT"
echo "OVERALL:         $OVERALL"
echo
echo "GIT_HEAD: $GIT_HEAD"
echo "GIT_STATUS: $GIT_STATUS"
echo
echo "AIL_LOG:    $AIL_LOG"
echo "RACING_LOG: $RACING_LOG"
echo "=========================================="
echo
echo "Artifact:"
echo "$REPORT"
echo
echo "=== ARTIFACT ==="
cat "$REPORT"
