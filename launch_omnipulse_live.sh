#!/data/data/com.termux/files/usr/bin/bash
set -u

ROOT="$HOME/UL7RAVERSE"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
BASE="$ROOT/verification_artifacts/omnipulse"
OUT="$BASE/live/$TS"
REPORT="$OUT/OMNIPULSE_LIVE_STATUS.md"

mkdir -p "$OUT"

echo "============================================================"
echo " OMNIPULSE — ONE-SCRIPT LIVE LAUNCH"
echo "============================================================"
echo "TIMESTAMP=$TS"
echo

# ------------------------------------------------------------
# LOCATE NEWEST BUILD
# ------------------------------------------------------------
APP="$(find "$BASE" -type f -path '*/app/index.html' 2>/dev/null \
  | sort | tail -1 | sed 's|/index.html$||')"

if [ -z "$APP" ]; then
  echo "FINAL_DECISION=BLOCKED"
  echo "REASON=NO_OMNIPULSE_APP_FOUND"
  exit 1
fi

echo "APP=$APP"

# ------------------------------------------------------------
# VERIFY REQUIRED ARTIFACTS
# ------------------------------------------------------------
INDEX="$APP/index.html"
MANIFEST="$APP/MANIFEST.json"

if [ ! -f "$INDEX" ]; then
  echo "FINAL_DECISION=BLOCKED"
  echo "REASON=INDEX_MISSING"
  exit 1
fi

if [ ! -f "$MANIFEST" ]; then
  echo "FINAL_DECISION=BLOCKED"
  echo "REASON=MANIFEST_MISSING"
  exit 1
fi

echo "INDEX_OK=1"
echo "MANIFEST_OK=1"

# ------------------------------------------------------------
# STOP ONLY OUR OLD LOCAL OMNIPULSE SERVER
# ------------------------------------------------------------
if [ -f "$BASE/live/.pid" ]; then
  OLD_PID="$(cat "$BASE/live/.pid" 2>/dev/null || true)"
  if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    kill "$OLD_PID" 2>/dev/null || true
    sleep 1
  fi
fi

# ------------------------------------------------------------
# START LIGHTWEIGHT LOCAL SERVER
# ------------------------------------------------------------
cd "$APP"

nohup python -m http.server 8787 --bind 127.0.0.1 \
  > "$OUT/http.log" 2>&1 &

PID=$!
echo "$PID" > "$BASE/live/.pid"

sleep 2

# ------------------------------------------------------------
# LOCAL HTTP TEST
# ------------------------------------------------------------
HTTP_CODE="$(curl -s -o /dev/null -w '%{http_code}' \
  http://127.0.0.1:8787/ 2>/dev/null || echo 000)"

if [ "$HTTP_CODE" = "200" ]; then
  LOCAL_OK=1
else
  LOCAL_OK=0
fi

echo "LOCAL_HTTP=$HTTP_CODE"
echo "LOCAL_OK=$LOCAL_OK"

# ------------------------------------------------------------
# BASIC CONTENT TEST
# ------------------------------------------------------------
if curl -fsS http://127.0.0.1:8787/ 2>/dev/null \
  | grep -qi "OMNIPULSE"; then
  CONTENT_OK=1
else
  CONTENT_OK=0
fi

echo "CONTENT_OK=$CONTENT_OK"

# ------------------------------------------------------------
# INSPECT EXISTING CLOUDFLARE PROCESSES
# DO NOT CREATE A NEW TUNNEL AUTOMATICALLY.
# ------------------------------------------------------------
TUNNEL_PROCESS=0
TUNNEL_8787=0

if command -v cloudflared >/dev/null 2>&1; then
  CLOUDFLARED_VERSION="$(cloudflared --version 2>/dev/null | head -1 || true)"
else
  CLOUDFLARED_VERSION="NOT_INSTALLED"
fi

ps -ef 2>/dev/null | grep '[c]loudflared' > "$OUT/cloudflared_processes.txt" || true

if [ -s "$OUT/cloudflared_processes.txt" ]; then
  TUNNEL_PROCESS=1

  if grep -Eq '8787|http://127\.0\.0\.1:8787|http://localhost:8787' \
      "$OUT/cloudflared_processes.txt"; then
    TUNNEL_8787=1
  fi
fi

echo "CLOUDFLARED=$CLOUDFLARED_VERSION"
echo "TUNNEL_PROCESS=$TUNNEL_PROCESS"
echo "TUNNEL_8787=$TUNNEL_8787"

# ------------------------------------------------------------
# OPTIONAL TUNNEL LIST — INFORMATION ONLY
# ------------------------------------------------------------
if command -v cloudflared >/dev/null 2>&1; then
  cloudflared tunnel list > "$OUT/tunnel_list.txt" 2>&1 || true
else
  echo "cloudflared unavailable" > "$OUT/tunnel_list.txt"
fi

# ------------------------------------------------------------
# COPY FINAL PUBLIC-FACING ENTRYPOINT
# ------------------------------------------------------------
cat > "$OUT/GATE_MESSAGE.txt" <<'GATE'
🎡 FIND YOUR FAIR

Not sure where to start?
OmniPulse builds your Fair.

🔥 Can’t Miss
🍔 Best Eats
🎵 What’s On
👨‍👩‍👧 Family
💰 Best Value
⚠️ Know Before You Go

SCAN → BUILD YOUR FAIR

Free.
GATE

# ------------------------------------------------------------
# GOVERNANCE DECISION
# ------------------------------------------------------------
if [ "$LOCAL_OK" = "1" ] && [ "$CONTENT_OK" = "1" ]; then
  FINAL_DECISION="TEST"
  PRODUCTION_UNLOCK=0
else
  FINAL_DECISION="BLOCKED"
  PRODUCTION_UNLOCK=0
fi

# Existing tunnel does NOT equal verified public reachability.
if [ "$TUNNEL_PROCESS" = "1" ]; then
  PUBLIC_TUNNEL_STATE="EXISTING_TUNNEL_DETECTED"
else
  PUBLIC_TUNNEL_STATE="NO_EXISTING_TUNNEL_PROCESS_DETECTED"
fi

# ------------------------------------------------------------
# FINAL REPORT
# ------------------------------------------------------------
cat > "$REPORT" <<REPORT
# OmniPulse Live Status

TIMESTAMP=$TS

## Build

APP=$APP
INDEX_OK=$([ -f "$INDEX" ] && echo 1 || echo 0)
MANIFEST_OK=$([ -f "$MANIFEST" ] && echo 1 || echo 0)

## Local Runtime

SERVER=python_http_server
BIND=127.0.0.1:8787
PID=$PID
HTTP_CODE=$HTTP_CODE
LOCAL_OK=$LOCAL_OK
CONTENT_OK=$CONTENT_OK

## Cloudflare

CLOUDFLARED=$CLOUDFLARED_VERSION
TUNNEL_PROCESS=$TUNNEL_PROCESS
TUNNEL_8787=$TUNNEL_8787
PUBLIC_TUNNEL_STATE=$PUBLIC_TUNNEL_STATE

## Governance

REAL_VISITOR=0
REAL_VENDOR=0
PAYMENT_VERIFIED=0
VERIFIED_REVENUE_CAD=0
PROOF_OK=0
PRODUCTION_UNLOCK=$PRODUCTION_UNLOCK
CANONICAL_PROMOTION=0

FINAL_DECISION=$FINAL_DECISION

## Rule

Local runtime success is not public-production proof.
Existing tunnel detection is not public reachability proof.
No proof -> trusted action.
No payment -> revenue claim.
No real visitor -> production promotion remains blocked.

## Gate Message

See:
$OUT/GATE_MESSAGE.txt
REPORT

# ------------------------------------------------------------
# FINAL OUTPUT
# ------------------------------------------------------------
echo
echo "============================================================"
echo " OMNIPULSE LIVE TEST READY"
echo "============================================================"
echo "APP:        $APP/index.html"
echo "LOCAL:      http://127.0.0.1:8787/"
echo "REPORT:     $REPORT"
echo "GATE:       $OUT/GATE_MESSAGE.txt"
echo "CLOUDFLARE: $PUBLIC_TUNNEL_STATE"
echo
echo "LOCAL_OK=$LOCAL_OK"
echo "CONTENT_OK=$CONTENT_OK"
echo "TUNNEL_PROCESS=$TUNNEL_PROCESS"
echo "TUNNEL_8787=$TUNNEL_8787"
echo
echo "FINAL_DECISION=$FINAL_DECISION"
echo "PRODUCTION_UNLOCK=$PRODUCTION_UNLOCK"
echo "============================================================"
