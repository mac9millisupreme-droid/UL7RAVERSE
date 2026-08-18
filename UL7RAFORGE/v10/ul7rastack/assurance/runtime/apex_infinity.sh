#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT="$HOME/UL7RAVERSE/UL7RAFORGE"
cd "$ROOT"

BASE="v10/ul7rastack/assurance/runtime"
STATE="$BASE/state.json"
LINEAGE="$BASE/lineage"
LOG="$BASE/apex_infinity.log"

mkdir -p "$BASE"

python3 - "$STATE" <<'PY'
import json,sys
from pathlib import Path

p=Path(sys.argv[1])

if not p.exists():
    raise SystemExit("BLOCKED: STATE_MISSING")

try:
    s=json.loads(p.read_text())
except Exception as e:
    raise SystemExit(f"BLOCKED: STATE_MALFORMED: {e}")

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
    raise SystemExit("BLOCKED: BASELINE_NOT_S8")

if s["candidate_version"] != "S9":
    raise SystemExit("BLOCKED: CANDIDATE_NOT_S9")

if not isinstance(s["iteration_count"],int):
    raise SystemExit("BLOCKED: ITERATION_INVALID")

print("STATE=VALID")
print("BASELINE=S8")
print("CANDIDATE=S9")
print("ITERATION="+str(s["iteration_count"]))
PY

echo
echo "========================================"
echo "UL7RAFORGE APEX INFINITY"
echo "========================================"
echo "STATE VALIDATED"

echo
echo "[1] VERIFY S8 BASELINE"

S8_MANIFEST="$LINEAGE/S8/manifest.json"
S8_LOCK="$BASE/s8_baseline.sha256"

test -f "$S8_MANIFEST" || {
    echo "S8_BASELINE=BLOCKED"
    exit 1
}

test -f "$S8_LOCK" || {
    echo "S8_BASELINE=BLOCKED"
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

echo
echo "[2] LOCATE S9 CANDIDATE"

S9_LATEST="$(
find "$LINEAGE/S9" \
    -mindepth 1 \
    -maxdepth 1 \
    -type d \
    -printf '%f\n' 2>/dev/null |
sort |
tail -1
)"

if [ -z "$S9_LATEST" ]; then
    echo "S9_CANDIDATE=NOT_FOUND"
    exit 1
fi

S9="$LINEAGE/S9/$S9_LATEST"

echo "S9_SNAPSHOT=$S9"

test -f "$S9/evidence.json" || {
    echo "EVIDENCE=BLOCKED"
    exit 1
}

test -f "$S9/release_gate.json" || {
    echo "RELEASE_GATE=BLOCKED"
    exit 1
}

echo
echo "[3] VERIFY S9 LINEAGE"

python3 - "$S9/evidence.json" "$S9/release_gate.json" "$STATE" <<'PY'
import json,sys
from pathlib import Path

e=json.loads(Path(sys.argv[1]).read_text())
g=json.loads(Path(sys.argv[2]).read_text())
s=json.loads(Path(sys.argv[3]).read_text())

assert e["baseline_version"]=="S8"
assert e["candidate_version"]=="S9"
assert g["baseline"]=="S8"
assert g["candidate"]=="S9"
assert g["production"]=="LOCKED"
assert g["certification_claim"] is False

print("LINEAGE=PASS")
print("PRODUCTION=LOCKED")
print("CERTIFICATION_CLAIM=FALSE")
PY

echo
echo "[4] RUN HYPER QUANTUM REGRESSION"

HQ="v10/ul7rastack/hyperquantum/verification/run.py"
HQ_OUT="$S9/apex_hyperquantum"
mkdir -p "$HQ_OUT"

if python3 "$HQ" "$HQ_OUT" > "$HQ_OUT/run.log" 2>&1; then
    echo "HYPER_QUANTUM=PASS"
else
    echo "HYPER_QUANTUM=BLOCKED"
    exit 1
fi

echo
echo "[5] APEX DECISION"

python3 - "$STATE" "$S9" <<'PY'
import json,sys
from pathlib import Path
from datetime import datetime,timezone

state=Path(sys.argv[1])
snap=Path(sys.argv[2])

s=json.loads(state.read_text())
iteration=s["iteration_count"]+1

s["iteration_count"]=iteration
s["last_state"]="S9_CANDIDATE"
s["last_exit_code"]=0
s["last_snapshot"]=str(snap)
s["last_successful_iteration"]=iteration
s["last_failure_reason"]=None

state.write_text(json.dumps(s,indent=2,sort_keys=True))

result={
    "engine":"APEX_INFINITY",
    "iteration":iteration,
    "baseline":"S8",
    "candidate":"S9",
    "state":"S9_CANDIDATE",
    "production":"LOCKED",
    "certification":"NOT_ESTABLISHED",
    "next_action":"INDEPENDENT_VERIFICATION",
    "timestamp":datetime.now(timezone.utc).isoformat()
}

(snap/"apex_result.json").write_text(
    json.dumps(result,indent=2,sort_keys=True)
)

print(json.dumps(result,indent=2,sort_keys=True))
PY

echo
echo "========================================"
echo "APEX INFINITY RESULT"
echo "========================================"
echo "BASELINE=S8"
echo "CANDIDATE=S9"
echo "STATE=STATEFUL"
echo "BASELINE_INVARIANT=PASS"
echo "LINEAGE=PASS"
echo "HYPER_QUANTUM=PASS"
echo "PRODUCTION=LOCKED"
echo "NEXT=INDEPENDENT_VERIFICATION"
echo "========================================"
