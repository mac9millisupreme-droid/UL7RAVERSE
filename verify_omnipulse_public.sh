#!/data/data/com.termux/files/usr/bin/bash
set -u

ROOT="$HOME/UL7RAVERSE"
BASE="$ROOT/verification_artifacts/omnipulse/force-live"
LATEST="$(find "$BASE" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | tail -1)"
OUT="$LATEST/public-verification"

mkdir -p "$OUT"

PORT=8899
LOCAL="http://127.0.0.1:$PORT"

echo "============================================================"
echo " OMNIPULSE × UL7RAVERSE × MAC9RECORDS"
echo " PUBLIC VERIFICATION"
echo "============================================================"
echo

# Find the currently running ephemeral tunnel URL.
PUBLIC_URL="$(
  find "$BASE" -name 'cloudflare.log' -type f -print0 2>/dev/null |
  xargs -0 cat 2>/dev/null |
  grep -Eo 'https://[-a-zA-Z0-9]+\.trycloudflare\.com' |
  tail -1
)"

if [ -z "$PUBLIC_URL" ]; then
  echo "PUBLIC_URL_NOT_FOUND"
  echo "FINAL_DECISION=BLOCKED"
  exit 1
fi

echo "PUBLIC_URL=$PUBLIC_URL"
echo "LOCAL=$LOCAL"
echo

# Confirm local source is still alive.
LOCAL_CODE="$(
  curl -s --connect-timeout 3 --max-time 8 \
  -o "$OUT/local.html" \
  -w '%{http_code}' \
  "$LOCAL/" 2>/dev/null
)"
LOCAL_CODE="${LOCAL_CODE:-000}"

echo "LOCAL_HTTP=$LOCAL_CODE"

# ------------------------------------------------------------
# PUBLIC RETRY WINDOW
# ------------------------------------------------------------
PUBLIC_CODE=000
PUBLIC_OK=0

for i in $(seq 1 45); do

  CODE="$(
    curl -L -sS \
      --connect-timeout 5 \
      --max-time 12 \
      -o "$OUT/public.html" \
      -w '%{http_code}' \
      "$PUBLIC_URL/" 2>"$OUT/curl_error.txt"
  )"

  CODE="${CODE:-000}"

  echo "PUBLIC_ATTEMPT=$i HTTP=$CODE"

  if [ "$CODE" = "200" ]; then
    PUBLIC_CODE=200
    break
  fi

  sleep 2
done

# ------------------------------------------------------------
# PUBLIC CONTENT VALIDATION
# ------------------------------------------------------------
P_OMNI=0
P_UL7=0
P_MAC9=0
P_FAIR=0
P_BUILD=0

if [ -f "$OUT/public.html" ]; then
  grep -qi "OMNIPULSE" "$OUT/public.html" && P_OMNI=1
  grep -qi "UL7RAVERSE" "$OUT/public.html" && P_UL7=1
  grep -qi "MAC9RECORDS" "$OUT/public.html" && P_MAC9=1
  grep -qi "FIND YOUR FAIR" "$OUT/public.html" && P_FAIR=1
  grep -qi "BUILD YOUR FAIR" "$OUT/public.html" && P_BUILD=1
fi

if [ "$PUBLIC_CODE" = "200" ] &&
   [ "$P_OMNI" = "1" ] &&
   [ "$P_UL7" = "1" ] &&
   [ "$P_MAC9" = "1" ] &&
   [ "$P_FAIR" = "1" ] &&
   [ "$P_BUILD" = "1" ]; then
  PUBLIC_OK=1
fi

# ------------------------------------------------------------
# GOVERNANCE
# ------------------------------------------------------------
if [ "$LOCAL_CODE" = "200" ] && [ "$PUBLIC_OK" = "1" ]; then
  FINAL_DECISION="TEST"
else
  FINAL_DECISION="BLOCKED"
fi

cat > "$OUT/FINAL_PUBLIC_STATUS.md" <<REPORT
# OmniPulse × UL7RAVERSE × MAC9RECORDS Public Verification

PUBLIC_URL=$PUBLIC_URL
LOCAL_HTTP=$LOCAL_CODE
PUBLIC_HTTP=$PUBLIC_CODE

OMNIPULSE=$P_OMNI
UL7RAVERSE=$P_UL7
MAC9RECORDS=$P_MAC9
FIND_YOUR_FAIR=$P_FAIR
BUILD_YOUR_FAIR=$P_BUILD

PUBLIC_OK=$PUBLIC_OK

REAL_VISITOR=0
REAL_VENDOR=0
PAYMENT_VERIFIED=0
VERIFIED_REVENUE_CAD=0
PROOF_OK=0

PRODUCTION_UNLOCK=0
CANONICAL_PROMOTION=0

FINAL_DECISION=$FINAL_DECISION

Public reachability is not endorsement.
Public reachability is not verified proof.
Public reachability is not verified revenue.
REPORT

echo
echo "============================================================"
echo " PUBLIC VERIFICATION RESULT"
echo "============================================================"
echo
echo "PUBLIC_URL=$PUBLIC_URL"
echo "LOCAL_HTTP=$LOCAL_CODE"
echo "PUBLIC_HTTP=$PUBLIC_CODE"
echo
echo "OMNIPULSE=$P_OMNI"
echo "UL7RAVERSE=$P_UL7"
echo "MAC9RECORDS=$P_MAC9"
echo "FIND_YOUR_FAIR=$P_FAIR"
echo "BUILD_YOUR_FAIR=$P_BUILD"
echo
echo "PUBLIC_OK=$PUBLIC_OK"
echo "REPORT=$OUT/FINAL_PUBLIC_STATUS.md"
echo
echo "FINAL_DECISION=$FINAL_DECISION"
echo "PRODUCTION_UNLOCK=0"
echo "============================================================"
