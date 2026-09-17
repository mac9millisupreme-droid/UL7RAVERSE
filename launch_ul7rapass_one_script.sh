#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/UL7RAVERSE"
cd "$ROOT"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="verification_artifacts/ul7rapass/stripe_launch/$TS"
mkdir -p "$OUT"

echo "=== UL7RAPASS ONE-SCRIPT LAUNCH GATE ==="
echo "TIME_UTC=$TS"
echo "REPO=$(git rev-parse --show-toplevel)"
echo "COMMIT=$(git rev-parse HEAD)"
echo

cat > "$OUT/UL7RAPASS_CHECKOUT_SPEC.json" <<'JSON'
{
  "offer": "UL7RAPASS",
  "currency": "CAD",
  "price_cad": 500,
  "amount_minor": 50000,
  "payment_model": "ONE_TIME",
  "term": "12_MONTHS",
  "surface": "HOSTED_CHECKOUT",
  "environment": "SANDBOX",
  "revenue_verified": false,
  "e6_01": "NOT_YET_VERIFIED",
  "governance": {
    "no_proof_no_trusted_action": true,
    "unverified_is_not_pass": true,
    "unknown_is_unknown": true,
    "fail_closed": true
  }
}
JSON

echo "=== CHECKOUT SPEC ==="
cat "$OUT/UL7RAPASS_CHECKOUT_SPEC.json"
echo

echo "=== TEST SUITE ==="
if command -v pytest >/dev/null 2>&1 && [ -d tests ]; then
    pytest -q
else
    echo "PYTEST_UNAVAILABLE_OR_NO_TEST_DIR"
fi

echo
echo "=== COMMERCIAL GATE ==="

cat > "$OUT/E6_REVENUE_STATUS.md" <<EOF
# UL7RAPASS E6 Revenue Status

AUDIT_TIME_UTC: $TS
REPO_COMMIT: $(git rev-parse HEAD)

## Offer

OFFER: UL7RAPASS
PRICE_CAD: 500
TERM: 12_MONTHS
PAYMENT_MODEL: ONE_TIME
ENVIRONMENT: SANDBOX

## Revenue

REVENUE_STATE: UNVERIFIED
CAD_REVENUE_VERIFIED: 0
E6_01: NOT_YET_VERIFIED

## Launch State

PRODUCT_STATE: OFFER_DEFINED
TECHNICAL_STATE: SANDBOX_CHECKOUT_CONFIGURATION_READY
LAUNCH_STATE: REQUIRES_LIVE_STRIPE_ACCOUNT_FOR_REAL_TRANSACTION

## Governance

NO_PROOF -> NO_TRUSTED_ACTION
UNVERIFIED -> NOT_PASS
UNKNOWN -> UNKNOWN
FAIL_CLOSED -> TRUE

## Required E6-01 Evidence

1. Legitimate CAD 500 live payment.
2. Stripe payment evidence.
3. Deterministic UL7RAPASS membership activation.
4. Activation evidence linked to the transaction.
5. Result recorded without fabricating revenue.

## Revenue Rule

Sandbox/test payments are NEVER counted as revenue.

15 verified memberships = CAD 7,500 verified revenue.

EOF

cat "$OUT/E6_REVENUE_STATUS.md"

echo
echo "=== FINAL DECISION ==="
echo "FINAL_DECISION: BLOCKED_FOR_LIVE_REVENUE"
echo "REASON: CONNECTED_STRIPE_ACCOUNT_IS_SANDBOX"
echo "NEXT_SINGLE_ACTION: CONNECT/SELECT_LIVE_STRIPE_ACCOUNT"
echo "E6_01: NOT_YET_VERIFIED"
echo "CAD_REVENUE_VERIFIED: 0"
echo
echo "Evidence: $OUT"
