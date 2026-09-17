#!/data/data/com.termux/files/usr/bin/bash
set -u

PORT=8899
LOCAL="http://127.0.0.1:$PORT"

ROOT="$HOME/UL7RAVERSE"
BASE="$ROOT/verification_artifacts/omnipulse/force-live"
LATEST="$(find "$BASE" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | tail -1)"

OUT="$LATEST/public-live-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT"

echo "============================================================"
echo " OMNIPULSE PUBLIC LIVE TEST"
echo "============================================================"

# Verify local app.
LOCAL_CODE="$(
  curl -sS --connect-timeout 3 --max-time 8 \
    -o "$OUT/local.html" \
    -w '%{http_code}' \
    "$LOCAL/" 2>/dev/null || true
)"

echo "LOCAL_HTTP=$LOCAL_CODE"

if [ "$LOCAL_CODE" != "200" ]; then
  echo "FINAL_DECISION=BLOCKED"
  exit 1
fi

# Kill ONLY previous quick tunnels targeting 8899.
pkill -f 'cloudflared tunnel --url http://127.0.0.1:8899' 2>/dev/null || true
pkill -f 'cloudflared tunnel --url http://localhost:8899' 2>/dev/null || true

sleep 2

LOG="$OUT/cloudflare.log"

echo "Starting persistent quick tunnel..."

# setsid prevents shell/job-control SIGHUP/SIGINT propagation.
setsid cloudflared tunnel \
  --url "$LOCAL" \
  --no-autoupdate \
  >"$LOG" 2>&1 < /dev/null &

PID=$!

echo "TUNNEL_PID=$PID"

PUBLIC_URL=""

for i in $(seq 1 30); do
  PUBLIC_URL="$(
    grep -Eo 'https://[-a-zA-Z0-9]+\.trycloudflare\.com' "$LOG" 2>/dev/null |
    tail -1
  )"

  [ -n "$PUBLIC_URL" ] && break
  sleep 1
done

echo "PUBLIC_URL=$PUBLIC_URL"

if [ -z "$PUBLIC_URL" ]; then
  echo "TUNNEL_URL=NOT_FOUND"
  echo "FINAL_DECISION=BLOCKED"
  tail -80 "$LOG"
  exit 1
fi

echo
echo "Testing public endpoint..."

PUBLIC_CODE=000

for i in $(seq 1 30); do

  CODE="$(
    curl -L -sS \
      --connect-timeout 5 \
      --max-time 12 \
      -o "$OUT/public.html" \
      -w '%{http_code}' \
      "$PUBLIC_URL/" \
      2>"$OUT/curl.err" || true
  )"

  echo "PUBLIC_ATTEMPT=$i HTTP=$CODE"

  if [ "$CODE" = "200" ]; then
    PUBLIC_CODE=200
    break
  fi

  sleep 2
done

OMNI=0
UL7=0
MAC9=0
FAIR=0
BUILD=0

grep -qi "OMNIPULSE" "$OUT/public.html" && OMNI=1
grep -qi "UL7RAVERSE" "$OUT/public.html" && UL7=1
grep -qi "MAC9RECORDS" "$OUT/public.html" && MAC9=1
grep -qi "FIND YOUR FAIR" "$OUT/public.html" && FAIR=1
grep -qi "BUILD YOUR FAIR" "$OUT/public.html" && BUILD=1

PUBLIC_OK=0

if [ "$PUBLIC_CODE" = "200" ] &&
   [ "$OMNI" = "1" ] &&
   [ "$UL7" = "1" ] &&
   [ "$MAC9" = "1" ] &&
   [ "$FAIR" = "1" ] &&
   [ "$BUILD" = "1" ]; then
  PUBLIC_OK=1
fi

if [ "$PUBLIC_OK" = "1" ]; then
  FINAL_DECISION="TEST"
else
  FINAL_DECISION="BLOCKED"
fi

cat > "$OUT/FINAL_STATUS.md" <<REPORT
# OmniPulse Public Live Test

PUBLIC_URL=$PUBLIC_URL
LOCAL_HTTP=$LOCAL_CODE
PUBLIC_HTTP=$PUBLIC_CODE

OMNIPULSE=$OMNI
UL7RAVERSE=$UL7
MAC9RECORDS=$MAC9
FIND_YOUR_FAIR=$FAIR
BUILD_YOUR_FAIR=$BUILD

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
echo " RESULT"
echo "============================================================"
echo "PUBLIC_URL=$PUBLIC_URL"
echo "LOCAL_HTTP=$LOCAL_CODE"
echo "PUBLIC_HTTP=$PUBLIC_CODE"
echo "OMNIPULSE=$OMNI"
echo "UL7RAVERSE=$UL7"
echo "MAC9RECORDS=$MAC9"
echo "FIND_YOUR_FAIR=$FAIR"
echo "BUILD_YOUR_FAIR=$BUILD"
echo "PUBLIC_OK=$PUBLIC_OK"
echo "REPORT=$OUT/FINAL_STATUS.md"
echo "FINAL_DECISION=$FINAL_DECISION"
echo "PRODUCTION_UNLOCK=0"
echo "============================================================"

if [ "$PUBLIC_OK" = "1" ]; then
  echo
  echo "PUBLIC TEST SURFACE IS LIVE."
  echo "NEXT: REAL-VISITOR TEST."
else
  echo
  echo "PUBLIC TEST FAILED."
  echo "--- CURL ERROR ---"
  cat "$OUT/curl.err" 2>/dev/null || true
  echo "--- CLOUDFLARE LOG ---"
  tail -80 "$LOG" 2>/dev/null || true
fi
