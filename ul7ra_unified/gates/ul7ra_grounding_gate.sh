#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${HOME}/UL7RAVERSE"
CENTER="$ROOT/grounded_center/UL7RAVERSE_GROUNDED_CENTER.json"
CONTRACT="$ROOT/ul7ra_unified/UL7RAVERSE_ECOSYSTEM_CONTRACT.json"

fail() {
  echo "FINAL_DECISION=BLOCK"
  echo "REASON=$1"
  exit 1
}

[ -f "$CENTER" ] || fail "CENTER_MISSING"
[ -f "$CONTRACT" ] || fail "CONTRACT_MISSING"

python - "$CENTER" "$CONTRACT" <<'PY'
import json
import hashlib
import sys

center_path = sys.argv[1]
contract_path = sys.argv[2]

with open(center_path, encoding="utf-8") as f:
    center = json.load(f)

with open(contract_path, encoding="utf-8") as f:
    contract = json.load(f)

required = [
    "grounding",
    "governance",
    "implementation_truth",
    "derivation_rule"
]

for key in required:
    if key not in center:
        print("GATE=FAIL")
        print("REASON=CENTER_MISSING_" + key.upper())
        sys.exit(1)

canonical = json.dumps(
    center,
    sort_keys=True,
    separators=(",", ":")
).encode()

actual = hashlib.sha256(canonical).hexdigest()

if contract["root"]["sha256"] != actual:
    print("GATE=FAIL")
    print("REASON=CENTER_HASH_MISMATCH")
    sys.exit(1)

if center["grounding"]["fail_closed"] is not True:
    print("GATE=FAIL")
    print("REASON=FAIL_CLOSED_NOT_ENABLED")
    sys.exit(1)

if center["grounding"]["unverified_never_passes"] is not True:
    print("GATE=FAIL")
    print("REASON=UNVERIFIED_POLICY_MISSING")
    sys.exit(1)

if center["grounding"]["unknown_remains_unknown"] is not True:
    print("GATE=FAIL")
    print("REASON=UNKNOWN_POLICY_MISSING")
    sys.exit(1)

print("CENTER=VALID")
print("CENTER_HASH=VALID")
print("GOVERNANCE=VALID")
print("FAIL_CLOSED=VALID")
print("UNKNOWN_POLICY=VALID")
print("DERIVATION_POLICY=VALID")
print("GATE=PASS")
print("FINAL_DECISION=PROCEED")
PY
