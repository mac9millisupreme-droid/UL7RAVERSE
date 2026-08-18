#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT="$HOME/UL7RAVERSE/UL7RAFORGE"
cd "$ROOT"

BASE="v10/ul7rastack/assurance"
RUNTIME="$BASE/runtime"
LINEAGE="$RUNTIME/lineage"
STATE="$RUNTIME/state.json"
LOG="$RUNTIME/apex_multiloop.log"

mkdir -p "$RUNTIME" "$LINEAGE/S9" "$LINEAGE/MVIV"

exec > >(tee -a "$LOG") 2>&1

echo "========================================"
echo "UL7RAFORGE APEX MULTI-LOOP"
echo "========================================"

# -------------------------------------------------
# 0. STATE VALIDATION
# -------------------------------------------------

python3 - "$STATE" <<'PY'
import json,sys
from pathlib import Path

p=Path(sys.argv[1])

if not p.exists():
    raise SystemExit("BLOCKED: STATE_MISSING")

try:
    s=json.loads(p.read_text())
except Exception:
    raise SystemExit("BLOCKED: STATE_MALFORMED")

required={
    "baseline_version",
    "candidate_version",
    "last_state",
    "last_exit_code",
    "last_snapshot",
    "last_evidence_hash",
    "iteration_count",
    "last_successful_iteration",
    "last_failure_reason"
}

missing=required-set(s)

if missing:
    raise SystemExit(
        "BLOCKED: STATE_FIELDS_MISSING=" +
        ",".join(sorted(missing))
    )

if s["baseline_version"] != "S8":
    raise SystemExit("BLOCKED: BASELINE_MUST_BE_S8")

if s["candidate_version"] != "S9":
    raise SystemExit("BLOCKED: CANDIDATE_MUST_BE_S9")

if not isinstance(s["iteration_count"],int):
    raise SystemExit("BLOCKED: ITERATION_INVALID")

print("STATE=PASS")
PY

# -------------------------------------------------
# 1. IMMUTABLE S8 CHECK
# -------------------------------------------------

echo "[1/10] TRUST ROOT"

S8_MANIFEST="$RUNTIME/lineage/S8/manifest.json"
S8_LOCK="$RUNTIME/s8_baseline.sha256"

test -f "$S8_MANIFEST" || {
    echo "BLOCKED: S8_MANIFEST_MISSING"
    exit 1
}

test -f "$S8_LOCK" || {
    echo "BLOCKED: S8_BASELINE_HASH_MISSING"
    exit 1
}

RECORDED="$(
python3 - "$S8_MANIFEST" <<'PY'
import json,sys
print(json.load(open(sys.argv[1]))["baseline_hash"])
PY
)"

CURRENT="$(
sha256sum "$S8_LOCK" | awk '{print $1}'
)"

if [ "$RECORDED" != "$CURRENT" ]; then
    echo "BASELINE_HASH_MUST_NOT_CHANGE=FAILED"
    exit 1
fi

echo "BASELINE_HASH_MUST_NOT_CHANGE=PASS"

# -------------------------------------------------
# 2. FIND LATEST S9
# -------------------------------------------------

echo "[2/10] CANDIDATE DISCOVERY"

S9_NAME="$(
find "$LINEAGE/S9" \
    -mindepth 1 \
    -maxdepth 1 \
    -type d \
    -printf '%f\n' |
sort |
tail -1
)"

if [ -z "$S9_NAME" ]; then
    echo "BLOCKED: NO_S9_CANDIDATE"
    exit 1
fi

S9="$LINEAGE/S9/$S9_NAME"

test -f "$S9/evidence.json" || {
    echo "BLOCKED: S9_EVIDENCE_MISSING"
    exit 1
}

echo "S9_SNAPSHOT=$S9"

# -------------------------------------------------
# 3. CREATE MVIV RUN
# -------------------------------------------------

echo "[3/10] INDEPENDENT VERIFIER"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
MVIV="$LINEAGE/MVIV/$TS"

mkdir -p "$MVIV"

# -------------------------------------------------
# 4. SOURCE / INPUT MANIFEST
# -------------------------------------------------

echo "[4/10] SOURCE MANIFEST"

find v10 \
    -type f \
    ! -path '*/runtime/lineage/MVIV/*' \
    ! -path '*/runtime/*.log' \
    -print0 |
sort -z |
xargs -0 sha256sum > "$MVIV/source_manifest.sha256"

sha256sum "$MVIV/source_manifest.sha256" \
    > "$MVIV/source_manifest.sha256.digest"

# -------------------------------------------------
# 5. FRESH BUILD LOOP
# -------------------------------------------------

echo "[5/10] BUILD LOOP"

BRIDGE="v10/ul7rabridge"

BUILD_STATUS="BLOCKED"

if [ -d "$BRIDGE" ] && command -v cargo >/dev/null 2>&1; then

    BUILD_A="$MVIV/build_a"
    mkdir -p "$BUILD_A"

    if (
        cd "$BRIDGE"
        cargo clean
        cargo build --release
    ) > "$BUILD_A/build.log" 2>&1; then

        if [ -f "$BRIDGE/target/release/cheetah" ]; then
            sha256sum \
                "$BRIDGE/target/release/cheetah" \
                > "$BUILD_A/artifact.sha256"

            BUILD_STATUS="PASS"
        fi
    fi
fi

echo "BUILD=$BUILD_STATUS"

# -------------------------------------------------
# 6. TEST LOOP
# -------------------------------------------------

echo "[6/10] TEST LOOP"

TEST_STATUS="BLOCKED"

if [ "$BUILD_STATUS" = "PASS" ]; then
    TEST_OUT="$MVIV/tests"
    mkdir -p "$TEST_OUT"

    if (
        cd "$BRIDGE"
        cargo test --release
    ) > "$TEST_OUT/cargo_test.log" 2>&1; then
        TEST_STATUS="PASS"
    else
        TEST_STATUS="FAIL"
    fi
fi

echo "TEST=$TEST_STATUS"

# -------------------------------------------------
# 7. PURPLE LOOP
# -------------------------------------------------

echo "[7/10] PURPLE LOOP"

PURPLE_STATUS="NOT_ESTABLISHED"

mkdir -p "$MVIV/purple"

cat > "$MVIV/purple/status.json" <<JSON
{
  "red_team": "NOT_ESTABLISHED",
  "blue_team": "NOT_ESTABLISHED",
  "purple_team": "NOT_ESTABLISHED",
  "authorized_environment_required": true,
  "production_testing": false,
  "status": "NOT_ESTABLISHED"
}
JSON

# Do not fabricate an attack result.
echo "PURPLE=NOT_ESTABLISHED"

# -------------------------------------------------
# 8. REPRODUCIBILITY LOOP
# -------------------------------------------------

echo "[8/10] REPRODUCIBILITY LOOP"

REPRO_STATUS="BLOCKED"

if [ "$BUILD_STATUS" = "PASS" ]; then

    BUILD_B="$MVIV/build_b"
    mkdir -p "$BUILD_B"

    if (
        cd "$BRIDGE"
        cargo clean
        cargo build --release
    ) > "$BUILD_B/build.log" 2>&1; then

        sha256sum \
            "$BRIDGE/target/release/cheetah" \
            > "$BUILD_B/artifact.sha256"

        HASH_A="$(
            awk '{print $1}' "$MVIV/build_a/artifact.sha256"
        )"

        HASH_B="$(
            awk '{print $1}' "$BUILD_B/artifact.sha256"
        )"

        if [ "$HASH_A" = "$HASH_B" ]; then
            REPRO_STATUS="PASS"
        else
            REPRO_STATUS="FAIL"
        fi

        cat > "$MVIV/reproducibility.json" <<JSON
{
  "build_a": "$HASH_A",
  "build_b": "$HASH_B",
  "match": $([ "$HASH_A" = "$HASH_B" ] && echo true || echo false),
  "status": "$REPRO_STATUS"
}
JSON
    fi
fi

echo "REPRODUCIBILITY=$REPRO_STATUS"

# -------------------------------------------------
# 9. INDEPENDENT DECISION ENGINE
# -------------------------------------------------

echo "[9/10] INDEPENDENT DECISION"

DECISION="BLOCKED"

if [ "$BUILD_STATUS" = "PASS" ] &&
   [ "$TEST_STATUS" = "PASS" ] &&
   [ "$REPRO_STATUS" = "PASS" ] &&
   [ "$PURPLE_STATUS" = "PASS" ]; then
    DECISION="VERIFIED"
fi

# Purple is deliberately not auto-promoted.
# Therefore this first MVIV run cannot falsely certify S9.

python3 - "$STATE" "$MVIV" "$DECISION" "$BUILD_STATUS" "$TEST_STATUS" "$REPRO_STATUS" "$PURPLE_STATUS" <<'PY'
import json,sys
from pathlib import Path
from datetime import datetime,timezone
import hashlib

state_path=Path(sys.argv[1])
mv=Path(sys.argv[2])

decision=sys.argv[3]
build=sys.argv[4]
test=sys.argv[5]
repro=sys.argv[6]
purple=sys.argv[7]

s=json.loads(state_path.read_text())

iteration=s["iteration_count"]+1

result={
    "verifier":"UL7RAFORGE_MVIV",
    "version":"MVIV-1",
    "baseline":"S8",
    "candidate":"S9",
    "iteration":iteration,
    "build":build,
    "test":test,
    "reproducibility":repro,
    "purple":purple,
    "decision":decision,
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

(mv/"independent_decision.json").write_text(
    json.dumps(result,indent=2,sort_keys=True)
)

s["iteration_count"]=iteration
s["last_state"]="VERIFIED" if decision=="VERIFIED" else "BLOCKED"
s["last_exit_code"]=0 if decision=="VERIFIED" else 1
s["last_snapshot"]=str(mv)
s["last_evidence_hash"]=result["evidence_hash"]

if decision=="VERIFIED":
    s["last_successful_iteration"]=iteration
    s["last_failure_reason"]=None
else:
    s["last_failure_reason"]="MVIV_GATE"

state_path.write_text(
    json.dumps(s,indent=2,sort_keys=True)
)

print(json.dumps(result,indent=2,sort_keys=True))
PY

# -------------------------------------------------
# 10. FINAL STATE
# -------------------------------------------------

echo "[10/10] FINAL STATE"

echo
echo "========================================"
echo "APEX MULTI-LOOP RESULT"
echo "========================================"
echo "BASELINE=S8"
echo "CANDIDATE=S9"
echo "BUILD=$BUILD_STATUS"
echo "TEST=$TEST_STATUS"
echo "PURPLE=$PURPLE_STATUS"
echo "REPRODUCIBILITY=$REPRO_STATUS"
echo "INDEPENDENT_DECISION=$DECISION"
echo "PRODUCTION=LOCKED"
echo "MVIV=$MVIV"
echo "========================================"

exit 0
