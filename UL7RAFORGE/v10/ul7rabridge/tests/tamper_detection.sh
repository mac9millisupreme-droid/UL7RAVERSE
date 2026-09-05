#!/data/data/com.termux/files/usr/bin/bash
set -eu

STATUS="../../ul7rastack/live/state/live_status.json"
BACKUP="${STATUS}.bak"

cp "$STATUS" "$BACKUP"
trap 'mv "$BACKUP" "$STATUS"' EXIT

python - "$STATUS" <<'PY'
import json, sys

p = sys.argv[1]
d = json.load(open(p))
d["exceptions"] = 999
open(p, "w").write(json.dumps(d, indent=2))
PY

if python ../../ul7rastack/verifier/src/verify.py "$STATUS" >/dev/null 2>&1; then
    echo "FAIL: tampered attestation accepted"
    exit 1
fi

echo "TAMPER DETECTION = PASS"
