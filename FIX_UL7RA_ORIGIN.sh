#!/data/data/com.termux/files/usr/bin/bash
set -u

ROOT="$HOME/UL7RAVERSE"
V99="$HOME/UL7RA_V99_LITE_TERMUX"
VERIFY="$ROOT/products/ul7ra-verify"

HOST="127.0.0.1"
PORT="8787"

RUNTIME="$ROOT/verification_artifacts/origin_runtime"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$RUNTIME/$TS"

mkdir -p "$OUT"

LOG="$OUT/origin.log"
PIDFILE="$OUT/origin.pid"

exec > >(tee "$OUT/EXECUTION.log") 2>&1

echo "============================================================"
echo " UL7RA ORIGIN REPAIR / START / VERIFY"
echo "============================================================"
echo "ROOT=$ROOT"
echo "V99=$V99"
echo "VERIFY=$VERIFY"
echo "TARGET=http://$HOST:$PORT"
echo "EVIDENCE=$OUT"
echo

echo "=== ENVIRONMENT ==="
command -v python || true
python --version || true
command -v curl || true
echo

echo "=== PORT CHECK ==="
if command -v lsof >/dev/null 2>&1; then
    lsof -i :"$PORT" 2>/dev/null || true
elif command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | grep ":$PORT " || true
fi
echo

echo "=== CANDIDATE DISCOVERY ==="

CANDIDATE=""

if [ -d "$V99" ]; then
    echo "V99_FOUND=$V99"
    find "$V99" -maxdepth 2 -type f \
        \( -name 'run.sh' -o -name 'start.sh' -o -name 'server.py' \
           -o -name 'main.py' -o -name 'app.py' -o -name 'package.json' \) \
        -print
fi

if [ -d "$VERIFY" ]; then
    echo "VERIFY_FOUND=$VERIFY"
    find "$VERIFY" -maxdepth 3 -type f \
        \( -name 'server.py' -o -name 'app.py' -o -name 'main.py' \
           -o -name 'pyproject.toml' -o -name 'requirements.txt' \) \
        -print
fi

echo
echo "=== PREFERRED V99 START ==="

if [ -x "$V99/run.sh" ]; then
    CANDIDATE="$V99/run.sh"
    CMD="$V99/run.sh"
elif [ -f "$V99/run.sh" ]; then
    CANDIDATE="$V99/run.sh"
    CMD="bash $V99/run.sh"
elif [ -f "$V99/server.py" ]; then
    CANDIDATE="$V99/server.py"
    CMD="python $V99/server.py"
elif [ -f "$V99/main.py" ]; then
    CANDIDATE="$V99/main.py"
    CMD="python $V99/main.py"
elif [ -f "$V99/app.py" ]; then
    CANDIDATE="$V99/app.py"
    CMD="python $V99/app.py"
fi

if [ -z "$CANDIDATE" ]; then
    echo "V99_START_SURFACE=NOT_FOUND"
else
    echo "V99_START_SURFACE=$CANDIDATE"
    echo "COMMAND=$CMD"
fi

echo
echo "=== START ==="

if [ -z "$CANDIDATE" ]; then
    echo "FINAL_DECISION=BLOCKED"
    echo "REASON=NO_V99_START_SURFACE"
    exit 1
fi

cd "$V99" || exit 1

nohup bash -c "$CMD" > "$LOG" 2>&1 &
PID=$!

echo "$PID" > "$PIDFILE"

echo "PID=$PID"
echo "LOG=$LOG"

sleep 3

if kill -0 "$PID" 2>/dev/null; then
    echo "PROCESS=RUNNING"
else
    echo "PROCESS=STOPPED"
    echo
    echo "=== STARTUP LOG ==="
    cat "$LOG" 2>/dev/null || true
    echo
    echo "FINAL_DECISION=BLOCKED"
    exit 1
fi

echo
echo "=== HEALTH CHECK ==="

if command -v curl >/dev/null 2>&1; then
    curl -sS --max-time 5 "http://$HOST:$PORT/health" \
        | tee "$OUT/health.json"
    CURL_EXIT=${PIPESTATUS[0]}
else
    python - <<PY
import urllib.request
u="http://$HOST:$PORT/health"
try:
    print(urllib.request.urlopen(u, timeout=5).read().decode())
except Exception as e:
    print("HEALTH_ERROR:", e)
    raise SystemExit(1)
PY
    CURL_EXIT=$?
fi

echo
echo "HEALTH_EXIT=$CURL_EXIT"

if [ "$CURL_EXIT" -eq 0 ]; then
    echo "ORIGIN=REACHABLE"
    FINAL="PASS_WITH_ENVIRONMENT_BLOCK"
else
    echo "ORIGIN=NOT_VERIFIED"
    FINAL="BLOCKED"
fi

echo
echo "=== FINAL ==="
echo "TESTED_START_SURFACE=$CANDIDATE"
echo "PROCESS_PID=$PID"
echo "HEALTH_EXIT=$CURL_EXIT"
echo "FINAL_DECISION=$FINAL"
echo "EVIDENCE=$OUT"

cat > "$OUT/FINAL_DECISION.md" <<EOF
# UL7RA Origin Execution

TIMESTAMP: $TS
TARGET: http://$HOST:$PORT
START_SURFACE: $CANDIDATE
PID: $PID
HEALTH_EXIT: $CURL_EXIT

ORIGIN_REACHABILITY:
$( [ "$CURL_EXIT" -eq 0 ] && echo PASS || echo BLOCKED )

GOVERNANCE:
UNVERIFIED_NEVER_PASS
UNKNOWN_REMAINS_UNKNOWN
NO_PROOF_NO_TRUSTED_ACTION
NO_SELF_CERTIFICATION
FAIL_CLOSED

FINAL_DECISION: $FINAL
EOF

cat "$OUT/FINAL_DECISION.md"
