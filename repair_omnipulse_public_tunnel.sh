#!/data/data/com.termux/files/usr/bin/bash
set -u

ROOT="$HOME/UL7RAVERSE"
BASE="$ROOT/verification_artifacts/omnipulse/force-live"
LATEST="$(find "$BASE" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | tail -1)"

PORT=8899
LOCAL="http://127.0.0.1:$PORT"
OUT="$LATEST/public-repair-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT"

echo "============================================================"
echo " OMNIPULSE PUBLIC TUNNEL REPAIR"
echo "============================================================"

echo
echo "LATEST=$LATEST"
echo "PORT=$PORT"

# ------------------------------------------------------------
# 1. VERIFY LOCAL APP
# ------------------------------------------------------------
LOCAL_CODE="$(
  curl -sS --connect-timeout 3 --max-time 8 \
    -o "$OUT/local.html" \
    -w '%{http_code}' \
    "$LOCAL/" 2>"$OUT/local_error.txt" || true
)"
LOCAL_CODE="${LOCAL_CODE:-000}"

echo "LOCAL_HTTP=$LOCAL_CODE"

if [ "$LOCAL_CODE" != "200" ]; then
  echo "LOCAL_SOURCE_BLOCKED=1"
  echo "FINAL_DECISION=BLOCKED"
  exit 1
fi

# ------------------------------------------------------------
# 2. STOP ONLY QUICK-TUNNEL PROCESSES
# ------------------------------------------------------------
echo
echo "Stopping stale cloudflared quick tunnels..."

pkill -f 'cloudflared tunnel --url http://127.0.0.1:8899' 2>/dev/null || true
pkill -f 'cloudflared tunnel --url http://localhost:8899' 2>/dev/null || true

sleep 2

# ------------------------------------------------------------
# 3. START A FRESH QUICK TUNNEL
# ------------------------------------------------------------
TUNNEL_LOG="$OUT/cloudflare.log"

echo "Starting fresh Cloudflare quick tunnel..."

nohup cloudflared tunnel \
  --url "$LOCAL" \
  --no-autoupdate \
  >"$TUNNEL_LOG" 2>&1 &

TUNNEL_PID=$!

echo "$TUNNEL_PID" > "$OUT/cloudflared.pid"

echo "TUNNEL_PID=$TUNNEL_PID"

# ------------------------------------------------------------
# 4. WAIT FOR CLOUDFLARE URL
# ------------------------------------------------------------
PUBLIC_URL=""

for i in $(seq 1 30); do
  PUBLIC_URL="$(
    grep -Eo 'https://[-a-zA-Z0-9]+\.trycloudflare\.com' \
      "$TUNNEL_LOG" 2>/dev/null |
      tail -1
  )"

  if [ -n "$PUBLIC_URL" ]; then
    break
  fi

  sleep 1
done

echo
echo "PUBLIC_URL=$PUBLIC_URL"

if [ -z "$PUBLIC_URL" ]; then
  echo "TUNNEL_URL=NOT_FOUND"
  echo "FINAL_DECISION=BLOCKED"
  echo
  echo "--- CLOUDFLARE LOG ---"
  cat "$TUNNEL_LOG"
  exit 1
fi

# ------------------------------------------------------------
# 5. VERIFY PUBLIC ENDPOINT
# ------------------------------------------------------------
PUBLIC_CODE=000
PUBLIC_OK=0

echo
echo "Testing public endpoint..."

for i in $(seq 1 60); do

  CODE="$(
    curl -L -sS \
      --connect-timeout 5 \
      --max-time 12 \
      -o "$OUT/public.html" \
      -w '%{http_code}' \
      "$PUBLIC_URL/" \
      2>"$OUT/public_curl_error.txt" || true
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
# 6. CONTENT CHECK
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
# 7. REPORT
# ------------------------------------------------------------
if [ "$LOCAL_CODE" = "200" ] && [ "$PUBLIC_OK" = "1" ]; then
  FINAL_DECISION="TEST"
else
  FINAL_DECISION="BLOCKED"
fi

cat > "$OUT/FINAL_STATUS.md" <<REPORT
# OmniPulse × UL7RAVERSE × MAC9RECORDS — Public Tunnel Repair

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
echo " RESULT"
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
echo "REPORT=$OUT/FINAL_STATUS.md"
echo
echo "FINAL_DECISION=$FINAL_DECISION"
echo "PRODUCTION_UNLOCK=0"
echo "============================================================"

if [ "$PUBLIC_OK" = "1" ]; then
  echo
  echo "PUBLIC TEST SURFACE IS REACHABLE."
  echo "NEXT STEP: REAL-VISITOR TEST."
else
  echo
  echo "PUBLIC TUNNEL STILL BLOCKED."
  echo
  echo "--- CURL ERROR ---"
  cat "$OUT/public_curl_error.txt" 2>/dev/null || true
  echo
  echo "--- CLOUDFLARE LOG ---"
  cat "$TUNNEL_LOG" 2>/dev/null || true
fi
