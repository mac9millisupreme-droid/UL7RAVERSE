#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="v10/ul7rastack/assurance/snapshots/$RUN_ID"
mkdir -p "$OUT"

echo "UL7RAFORGE ELITE EXECUTION"
echo "RUN_ID=$RUN_ID"
echo "ROOT=$ROOT"

run() {
    name="$1"
    shift

    echo
    echo "=== $name ==="

    if "$@" >"$OUT/$name.log" 2>&1; then
        echo "STATUS=PASS"
        return 0
    fi

    echo "STATUS=FAIL"
    cat "$OUT/$name.log"
    return 1
}

FAIL=0

run PYTHON_COMPILE \
    python3 -m compileall -q v10 || FAIL=1

if [[ -f v10/ul7rastack/assurance/assurance_gates.py ]]; then
    run ASSURANCE_GATES \
        python3 v10/ul7rastack/assurance/assurance_gates.py || FAIL=1
else
    echo "ASSURANCE_GATES=BLOCKED"
    FAIL=1
fi

if [[ -f v10/ul7rastack/echoless/core.py ]]; then
    run ECHOLESS \
        python3 v10/ul7rastack/echoless/core.py || FAIL=1
else
    echo "ECHOLESS=BLOCKED"
    FAIL=1
fi

if [[ -f v10/ul7rastack/core/sovereign_core.py ]]; then
    run SOVEREIGN_CORE \
        python3 v10/ul7rastack/core/sovereign_core.py || FAIL=1
else
    echo "SOVEREIGN_CORE=BLOCKED"
    FAIL=1
fi

if [[ -f v10/tests/high_assurance_regression.sh ]]; then
    run HIGH_ASSURANCE_REGRESSION \
        bash v10/tests/high_assurance_regression.sh || FAIL=1
else
    echo "HIGH_ASSURANCE_REGRESSION=BLOCKED"
    FAIL=1
fi

if [[ -f v10/tests/veriscore_regression.sh ]]; then
    run VERISCORE_REGRESSION \
        bash v10/tests/veriscore_regression.sh || FAIL=1
else
    echo "VERISCORE_REGRESSION=BLOCKED"
    FAIL=1
fi

python3 - "$OUT" "$FAIL" <<'PY'
import json
import hashlib
import sys
from pathlib import Path
from datetime import datetime, timezone

out = Path(sys.argv[1])
failed = int(sys.argv[2]) != 0

results = {}

for p in out.glob("*.log"):
    text = p.read_text(errors="replace")
    results[p.stem] = {
        "status": "PASS" if "STATUS=PASS" in text else "FAIL"
    }

result = {
    "system": "UL7RAVERSE",
    "factory": "UL7RAFORGE",
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "status": "BLOCKED" if failed else "ELIGIBLE_FOR_RELEASE_GATE",
    "production": "LOCKED",
    "certification_claim": False,
    "rule": "UNVERIFIED_NEVER_EQUALS_PASS",
    "execution_results": results,
}

canonical = json.dumps(
    result,
    sort_keys=True,
    separators=(",", ":")
).encode()

result["evidence_hash"] = hashlib.sha256(canonical).hexdigest()

(out / "system_result.json").write_text(
    json.dumps(result, indent=2, sort_keys=True)
)

print(json.dumps(result, indent=2, sort_keys=True))
PY

ln -sfn "$(basename "$OUT")" \
    v10/ul7rastack/assurance/snapshots/latest

echo
echo "========================================"
echo "UL7RAFORGE EXECUTION COMPLETE"
echo "========================================"
echo "SNAPSHOT=$OUT"
echo "LATEST=v10/ul7rastack/assurance/snapshots/latest"
echo "PRODUCTION=LOCKED"

if [[ "$FAIL" -eq 0 ]]; then
    echo "RELEASE_GATE=ELIGIBLE_FOR_RELEASE_GATE"
else
    echo "RELEASE_GATE=BLOCKED"
fi

exit "$FAIL"
