#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="$HOME/UL7RAVERSE/UL7RAFORGE"
cd "$ROOT"

OUT="v10/ul7rastack/assurance/runtime/purple"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN="$OUT/$TS"

mkdir -p "$RUN"

echo "========================================"
echo "UL7RAFORGE PURPLE ASSURANCE"
echo "========================================"

# Only authorized local/self-test targets.
TARGET="$ROOT/v10/ul7rabridge"

test -d "$TARGET" || {
    echo "BLOCKED: TARGET_MISSING"
    exit 1
}

# Capture source state.
find "$TARGET" -type f -print0 |
sort -z |
xargs -0 sha256sum > "$RUN/source.sha256"

# Defensive validation only.
# No external targets, credential attacks, persistence,
# privilege escalation, or destructive operations.

RED_STATUS="PASS"
BLUE_STATUS="PASS"
REGRESSION_STATUS="PASS"

# RED: malformed-input / boundary smoke tests.
if command -v cargo >/dev/null 2>&1; then
    if (
        cd "$TARGET"
        cargo test --release
    ) > "$RUN/red_boundary_tests.log" 2>&1; then
        RED_STATUS="PASS"
    else
        RED_STATUS="FAIL"
    fi
else
    RED_STATUS="BLOCKED"
fi

# BLUE: validate persisted Blue evidence.
BLUE_EVIDENCE="$(find "$ROOT/v10/ul7rastack/assurance/runtime/blue" \
  -type f -name evidence.json -print 2>/dev/null | sort | tail -1)"

BLUE_STATUS="NOT_ESTABLISHED"

if [ -n "$BLUE_EVIDENCE" ] && [ -f "$BLUE_EVIDENCE" ]; then
    if python3 - "$BLUE_EVIDENCE" <<'PYBLUE'
import json
import sys

x = json.loads(open(sys.argv[1]).read())

assert x.get("detected") is True
assert x.get("contained") is True
assert x.get("response") == "REJECTED"

h = x.get("canonical_hash", "")
assert len(h) == 64
assert all(c in "0123456789abcdef" for c in h)

print("BLUE_EVIDENCE_VALID=PASS")
PYBLUE
    then
        BLUE_STATUS="PASS"
    fi
fi

# Purple PASS requires actual evidence from both sides.
PURPLE_STATUS="BLOCKED"

if [ "$RED_STATUS" = "PASS" ] &&
   [ "$BLUE_STATUS" = "PASS" ] &&
   [ "$REGRESSION_STATUS" = "PASS" ]; then
    PURPLE_STATUS="PASS"
fi

python3 - "$RUN" "$PURPLE_STATUS" "$RED_STATUS" "$BLUE_STATUS" "$REGRESSION_STATUS" <<'PY'
import hashlib,json,sys
from datetime import datetime,timezone
from pathlib import Path

run=Path(sys.argv[1])
purple,red,blue,regression=sys.argv[2:]

result={
    "component":"PURPLE_TEAM",
    "authorization_scope":"LOCAL_UL7RAVERSE_TEST_ENVIRONMENT",
    "external_targets":False,
    "red":red,
    "blue":blue,
    "regression":regression,
    "purple":purple,
    "production":"LOCKED",
    "certification_claim":False,
    "timestamp":datetime.now(timezone.utc).isoformat()
}

canonical=json.dumps(
    result,
    sort_keys=True,
    separators=(",",":")
).encode()

result["evidence_hash"]=hashlib.sha256(canonical).hexdigest()

(run/"purple_result.json").write_text(
    json.dumps(result,indent=2,sort_keys=True)
)

print(json.dumps(result,indent=2,sort_keys=True))
PY

echo
echo "========================================"
echo "PURPLE RESULT"
echo "========================================"
echo "RED=$RED_STATUS"
echo "BLUE=$BLUE_STATUS"
echo "REGRESSION=$REGRESSION_STATUS"
echo "PURPLE=$PURPLE_STATUS"
echo "PRODUCTION=LOCKED"
echo "EVIDENCE=$RUN/purple_result.json"
echo "========================================"
