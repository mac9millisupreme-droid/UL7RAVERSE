#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/UL7RAVERSE"
LD="$ROOT/lucideploy"
APEX="$HOME/UL7RA4ORGE_APEX"
TRINITY="$HOME/TRINITY_CORE"
PRODUCT="$ROOT/products/ul7ra-verify"
OUT="$LD/evidence/final_gate.json"

mkdir -p "$LD/evidence"

PASS=0
BLOCK=0

check() {
    local name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo "$name=PASS"
        PASS=$((PASS+1))
        return 0
    else
        echo "$name=FAIL"
        BLOCK=$((BLOCK+1))
        return 1
    fi
}

echo "============================================================"
echo " LUCIDEPLOY FINAL GATE"
echo "============================================================"

cd "$ROOT"

UL7RA_HEAD="$(git rev-parse HEAD)"
TRINITY_HEAD="$(git -C "$TRINITY" rev-parse HEAD)"
APEX_SHA="$(sha256sum "$APEX/ul7ra/core.py" | awk '{print $1}')"

echo
echo "=== AUTHORITIES ==="
echo "UL7RAVERSE_HEAD=$UL7RA_HEAD"
echo "TRINITY_HEAD=$TRINITY_HEAD"
echo "APEX_CORE_SHA256=$APEX_SHA"

echo
echo "=== ARTIFACT / INTEGRITY ==="

EXPECTED_APEX="12a29fab1b79908de6fea2de56f7b63ac46f48bd0ae51b6b31c2f3da97ce824e"

if [ "$APEX_SHA" = "$EXPECTED_APEX" ]; then
    echo "APEX_INTEGRITY=PASS"
    APEX_INTEGRITY=PASS
else
    echo "APEX_INTEGRITY=FAIL"
    APEX_INTEGRITY=FAIL
    BLOCK=$((BLOCK+1))
fi

if python3 -m compileall -q "$LD"; then
    echo "LUCIDEPLOY_COMPILE=PASS"
else
    echo "LUCIDEPLOY_COMPILE=FAIL"
    BLOCK=$((BLOCK+1))
fi

echo
echo "=== LUCIDEPLOY TESTS ==="

TEST_RESULT=PASS
LUCIDEPLOY_TESTS=PASS

for test in \
    "$LD/tests/test_integrity.py" \
    "$LD/tests/test_state.py"
do
    if python3 "$test"; then
        :
    else
        TEST_RESULT=FAIL
        BLOCK=$((BLOCK+1))
    fi
done

echo "LUCIDEPLOY_TESTS=$TEST_RESULT"

echo
echo "=== TRINITY ==="

TRINITY_RESULT=PASS

for f in \
    "$TRINITY/PROVENANCE.json" \
    "$TRINITY/governance/STATE.json" \
    "$TRINITY/evidence/evidence_v0.1.json" \
    "$TRINITY/qs/core.py"
do
    if [ -f "$f" ]; then
        echo "EXISTS=$f"
    else
        echo "MISSING=$f"
        TRINITY_RESULT=FAIL
        BLOCK=$((BLOCK+1))
    fi
done

echo "TRINITY_FILES=$TRINITY_RESULT"

echo
echo "=== PRODUCT ==="

PRODUCT_RESULT=PASS

for f in \
    "$PRODUCT/PRODUCT_CONTRACT.json" \
    "$PRODUCT/app/server.py" \
    "$PRODUCT/tests/test_server.py" \
    "$PRODUCT/scripts/verify_product.sh"
do
    if [ -f "$f" ]; then
        echo "EXISTS=$f"
    else
        echo "MISSING=$f"
        PRODUCT_RESULT=FAIL
        BLOCK=$((BLOCK+1))
    fi
done

if [ "$PRODUCT_RESULT" = PASS ]; then
    if bash "$PRODUCT/scripts/verify_product.sh"; then
        echo "PRODUCT_VERIFICATION=PASS"
    else
        echo "PRODUCT_VERIFICATION=FAIL"
        PRODUCT_RESULT=FAIL
        BLOCK=$((BLOCK+1))
    fi
fi

echo
echo "=== EXISTING DEPLOYMENT EVIDENCE ==="

LOCAL_HEALTH=BLOCKED
CLOUDFLARE=BLOCKED
PUBLIC_HTTP=BLOCKED
PRODUCTION_HOSTNAME=BLOCKED

LOCAL_FILE="$PRODUCT/deploy/runtime/local_verify.json"
URL_FILE="$PRODUCT/deploy/runtime/public_url"
HEALTH_FILE="$PRODUCT/deploy/runtime/public_health.json"

if [ -s "$LOCAL_FILE" ]; then
    if grep -q '"result": "VERIFIED_INPUT_RECEIVED"' "$LOCAL_FILE"; then
        LOCAL_HEALTH=PASS
    fi
fi

echo "LOCAL_HEALTH=$LOCAL_HEALTH"

if [ -s "$URL_FILE" ]; then
    PUBLIC_URL="$(cat "$URL_FILE")"
else
    PUBLIC_URL=""
fi

if [ -n "$PUBLIC_URL" ]; then
    echo "PUBLIC_URL=$PUBLIC_URL"

    if command -v curl >/dev/null 2>&1; then
        HTTP_CODE="$(curl -L -k -sS -o /dev/null -w '%{http_code}' \
            --max-time 15 "$PUBLIC_URL" || true)"

        echo "HTTP_STATUS=$HTTP_CODE"

        case "$HTTP_CODE" in
            2??|3??)
                PUBLIC_HTTP=PASS
                ;;
            *)
                PUBLIC_HTTP=FAIL
                BLOCK=$((BLOCK+1))
                ;;
        esac
    else
        echo "CURL=NOT_FOUND"
        PUBLIC_HTTP=BLOCKED
        BLOCK=$((BLOCK+1))
    fi
else
    echo "PUBLIC_URL=MISSING"
fi

echo "PUBLIC_HTTP=$PUBLIC_HTTP"

if pgrep -f cloudflared >/dev/null 2>&1; then
    CLOUDFLARE=PASS
else
    CLOUDFLARE=BLOCKED
fi

echo "CLOUDFLARE_PROCESS=$CLOUDFLARE"

echo
echo "=== PRODUCTION DISTINCTION ==="

echo "QUICK_TUNNEL_IS_PRODUCTION=FALSE"
echo "PUBLIC_HTTP_IS_PRODUCTION=FALSE"

echo
echo "=== FINAL DECISION ==="

# Production is deliberately NOT inferred from a quick tunnel.
# A named production hostname requires independent hostname verification.
if [ "$APEX_INTEGRITY" = PASS ] &&
   [ "$LUCIDEPLOY_TESTS" = PASS ] &&
   [ "$TRINITY_RESULT" = PASS ] &&
   [ "$PRODUCT_RESULT" = PASS ] &&
   [ "$LOCAL_HEALTH" = PASS ] &&
   [ "$PUBLIC_HTTP" = PASS ]; then

    PRODUCTION="BLOCKED"
    PROMOTION="BLOCKED"

    echo "CORE_VERIFICATION=PASS"
    echo "PRODUCTION=BLOCKED"
    echo "PROMOTION=BLOCKED"
    echo "REASON=PRODUCTION_HOSTNAME_NOT_PROVEN"
else
    PRODUCTION="BLOCKED"
    PROMOTION="BLOCKED"

    echo "CORE_VERIFICATION=BLOCKED"
    echo "PRODUCTION=BLOCKED"
    echo "PROMOTION=BLOCKED"
fi

TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat > "$OUT" <<JSON
{
  "schema": "LUCIDEPLOY-FINAL-GATE-1",
  "timestamp_utc": "$TIMESTAMP",
  "repository_head": "$UL7RA_HEAD",
  "trinity_head": "$TRINITY_HEAD",
  "apex_version": "0.4.1",
  "apex_core_sha256": "$APEX_SHA",
  "gates": {
    "artifact_integrity": "$APEX_INTEGRITY",
    "lucideploy_tests": "$LUCIDEPLOY_TESTS",
    "trinity": "$TRINITY_RESULT",
    "product": "$PRODUCT_RESULT",
    "local_health": "$LOCAL_HEALTH",
    "cloudflare_process": "$CLOUDFLARE",
    "public_http": "$PUBLIC_HTTP",
    "production_hostname": "$PRODUCTION_HOSTNAME"
  },
  "deployment": {
    "public_url": "$PUBLIC_URL",
    "quick_tunnel_is_production": false
  },
  "final": {
    "production": "$PRODUCTION",
    "promotion": "$PROMOTION"
  },
  "fail_closed": true
}
JSON

echo
echo "============================================================"
echo " LUCIDEPLOY FINAL EVIDENCE"
echo "============================================================"
echo "EVIDENCE=$OUT"
cat "$OUT"
echo
echo "FINAL=$PROMOTION"
