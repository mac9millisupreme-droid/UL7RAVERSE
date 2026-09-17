#!/data/data/com.termux/files/usr/bin/bash
set -u

export PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/bin:/system/bin:/system/xbin"

BASE="http://127.0.0.1:8787"
PID="23153"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$HOME/UL7RAVERSE/verification_artifacts/origin_runtime/VERIFY_FINAL_$TS"

mkdir -p "$OUT"

echo "=== UL7RA ORIGIN FINAL GOVERNED VERIFICATION ==="
echo "PATH=$PATH"
echo "BASE=$BASE"
echo "EVIDENCE=$OUT"

python - "$BASE" "$OUT" <<'PY'
import json, os, sys, urllib.request, urllib.error

base = sys.argv[1]
out = sys.argv[2]

results = {}

for name in ("health", "selftest", "integrity"):
    url = base + "/" + name
    try:
        with urllib.request.urlopen(url, timeout=5) as r:
            body = r.read().decode("utf-8", "replace")
            code = r.status
        results[name] = {"http": code, "body": body}
        print(f"{name.upper()}_HTTP={code}")
        print(body)
        open(os.path.join(out, name.upper() + ".json"), "w").write(body)
    except Exception as e:
        results[name] = {"http": 0, "error": repr(e)}
        print(f"{name.upper()}_HTTP=000")
        print(repr(e))

open(os.path.join(out, "RESULTS.json"), "w").write(
    json.dumps(results, indent=2)
)
PY

if kill -0 "$PID" 2>/dev/null; then
    PROCESS_OK=1
    PROCESS_STATE=RUNNING
else
    PROCESS_OK=0
    PROCESS_STATE=NOT_RUNNING
fi

python - "$OUT" "$PROCESS_OK" "$PROCESS_STATE" <<'PY'
import json, os, sys

out, process_ok, process_state = sys.argv[1:]
process_ok = int(process_ok)

try:
    results = json.load(open(os.path.join(out, "RESULTS.json")))
except Exception:
    results = {}

health = results.get("health", {})
selftest = results.get("selftest", {})
integrity = results.get("integrity", {})

health_ok = (
    health.get("http") == 200 and
    '"ok"' in health.get("body", "") and
    '"true"' in health.get("body", "")
)

selftest_ok = (
    selftest.get("http") == 200 and
    '"passed"' in selftest.get("body", "") and
    '"true"' in selftest.get("body", "")
)

integrity_ok = (
    integrity.get("http") == 200 and
    '"VALID"' in integrity.get("body", "")
)

final = (
    "PASS_WITH_ENVIRONMENT_BLOCK"
    if health_ok and selftest_ok and integrity_ok and process_ok
    else "BLOCKED"
)

decision = f"""# UL7RA Origin Final Governed Verification

HEALTH_OK: {int(health_ok)}
SELFTEST_OK: {int(selftest_ok)}
INTEGRITY_OK: {int(integrity_ok)}
PROCESS_OK: {process_ok}
PROCESS_STATE: {process_state}

STATE_AND_ROOT_ARE_OBSERVATIONAL_ONLY.

Governance:
UNVERIFIED_NEVER_PASS
UNKNOWN_REMAINS_UNKNOWN
NO_PROOF_NO_TRUSTED_ACTION
NO_SELF_CERTIFICATION
FAIL_CLOSED

FINAL_DECISION: {final}
"""

open(os.path.join(out, "FINAL_DECISION.md"), "w").write(decision)
print()
print(decision)
PY

echo "EVIDENCE=$OUT"
