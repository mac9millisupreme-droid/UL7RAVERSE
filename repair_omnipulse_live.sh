#!/data/data/com.termux/files/usr/bin/bash
set -u

ROOT="$HOME/UL7RAVERSE"
BASE="$ROOT/verification_artifacts/omnipulse"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$BASE/live-repair/$TS"

mkdir -p "$OUT"

echo "============================================================"
echo " OMNIPULSE — LIVE REPAIR + PUBLIC TEST"
echo "============================================================"
echo "TIMESTAMP=$TS"
echo

APP="$(find "$BASE" -type f -path '*/app/index.html' 2>/dev/null \
  | sort | tail -1 | sed 's|/index.html$||')"

if [ -z "$APP" ]; then
  echo "FINAL_DECISION=BLOCKED"
  echo "REASON=NO_APP"
  exit 1
fi

INDEX="$APP/index.html"

echo "APP=$APP"

# ------------------------------------------------------------
# START LOCAL SERVER
# ------------------------------------------------------------
if curl -fsS http://127.0.0.1:8787/ >/dev/null 2>&1; then
  SERVER_RUNNING=1
else
  (
    cd "$APP"
    nohup python -m http.server 8787 --bind 127.0.0.1 \
      > "$OUT/http.log" 2>&1 &
    echo $! > "$OUT/server.pid"
  )
  sleep 2
  SERVER_RUNNING=0
  curl -fsS http://127.0.0.1:8787/ >/dev/null 2>&1 && SERVER_RUNNING=1
fi

# ------------------------------------------------------------
# ROBUST CONTENT VALIDATION
# ------------------------------------------------------------
curl -fsS http://127.0.0.1:8787/ > "$OUT/index_live.html" 2>/dev/null || true

HTTP_CODE="$(curl -s -o /dev/null -w '%{http_code}' \
  http://127.0.0.1:8787/ 2>/dev/null || echo 000)"

MARKERS=0

grep -qi "OMNIPULSE" "$OUT/index_live.html" && MARKERS=$((MARKERS+1))
grep -qi "BUILD MY FAIR" "$OUT/index_live.html" && MARKERS=$((MARKERS+1))
grep -qi "FIND YOUR FAIR" "$OUT/index_live.html" && MARKERS=$((MARKERS+1))

if [ "$HTTP_CODE" = "200" ] && [ "$MARKERS" -ge 2 ]; then
  CONTENT_OK=1
else
  CONTENT_OK=0
fi

echo "SERVER_RUNNING=$SERVER_RUNNING"
echo "HTTP_CODE=$HTTP_CODE"
echo "CONTENT_MARKERS=$MARKERS"
echo "CONTENT_OK=$CONTENT_OK"

# ------------------------------------------------------------
# EXISTING CLOUDFLARE EVIDENCE
# ------------------------------------------------------------
if command -v cloudflared >/dev/null 2>&1; then
  cloudflared --version > "$OUT/cloudflared_version.txt" 2>&1 || true
  cloudflared tunnel list > "$OUT/tunnel_list.txt" 2>&1 || true
else
  echo "NOT_INSTALLED" > "$OUT/cloudflared_version.txt"
  echo "NOT_INSTALLED" > "$OUT/tunnel_list.txt"
fi

ps -ef 2>/dev/null | grep '[c]loudflared' \
  > "$OUT/cloudflared_processes.txt" || true

# ------------------------------------------------------------
# DO NOT ASSUME EXISTING TUNNEL TARGET
# ------------------------------------------------------------
TUNNEL_PROCESS=0
TUNNEL_8787=0

if [ -s "$OUT/cloudflared_processes.txt" ]; then
  TUNNEL_PROCESS=1

  if grep -Eq '8787|127\.0\.0\.1:8787|localhost:8787' \
      "$OUT/cloudflared_processes.txt"; then
    TUNNEL_8787=1
  fi
fi

echo "TUNNEL_PROCESS=$TUNNEL_PROCESS"
echo "TUNNEL_8787=$TUNNEL_8787"

# ------------------------------------------------------------
# CONTROLLED EPHEMERAL PUBLIC TEST
# ------------------------------------------------------------
PUBLIC_URL=""

if [ "$CONTENT_OK" = "1" ] && command -v cloudflared >/dev/null 2>&1; then

  echo
  echo "Starting controlled OmniPulse public test tunnel..."

  nohup cloudflared tunnel --url http://127.0.0.1:8787 \
    > "$OUT/ephemeral_tunnel.log" 2>&1 &

  TUNNEL_PID=$!
  echo "$TUNNEL_PID" > "$OUT/ephemeral_tunnel.pid"

  for i in $(seq 1 20); do
    sleep 1

    PUBLIC_URL="$(grep -Eo 'https://[-a-zA-Z0-9]+\.trycloudflare\.com' \
      "$OUT/ephemeral_tunnel.log" 2>/dev/null | head -1 || true)"

    if [ -n "$PUBLIC_URL" ]; then
      break
    fi
  done
fi

if [ -n "$PUBLIC_URL" ]; then
  echo "EPHEMERAL_URL=$PUBLIC_URL"

  PUBLIC_CODE="$(curl -L -s -o "$OUT/public.html" \
    -w '%{http_code}' "$PUBLIC_URL/" 2>/dev/null || echo 000)"

  if [ "$PUBLIC_CODE" = "200" ]; then
    PUBLIC_OK=1
  else
    PUBLIC_OK=0
  fi
else
  PUBLIC_CODE=000
  PUBLIC_OK=0
fi

echo "PUBLIC_HTTP=$PUBLIC_CODE"
echo "PUBLIC_OK=$PUBLIC_OK"

# ------------------------------------------------------------
# GOVERNANCE
# ------------------------------------------------------------
if [ "$CONTENT_OK" = "1" ]; then
  FINAL_DECISION="TEST"
else
  FINAL_DECISION="BLOCKED"
fi

cat > "$OUT/STATUS.md" <<REPORT
# OmniPulse Live Repair Status

TIMESTAMP=$TS

APP=$APP

## Local

SERVER_RUNNING=$SERVER_RUNNING
HTTP_CODE=$HTTP_CODE
CONTENT_MARKERS=$MARKERS
CONTENT_OK=$CONTENT_OK

## Existing Cloudflare

TUNNEL_PROCESS=$TUNNEL_PROCESS
TUNNEL_8787=$TUNNEL_8787

## Controlled Public Test

EPHEMERAL_URL=$PUBLIC_URL
PUBLIC_HTTP=$PUBLIC_CODE
PUBLIC_OK=$PUBLIC_OK

## Governance

REAL_VISITOR=0
REAL_VENDOR=0
PAYMENT_VERIFIED=0
VERIFIED_REVENUE_CAD=0
PROOF_OK=0
PRODUCTION_UNLOCK=0
CANONICAL_PROMOTION=0

FINAL_DECISION=$FINAL_DECISION

## Interpretation

A local HTTP pass proves only local serving.
A public tunnel pass proves reachability only.
Neither constitutes production authorization.
Real visitor evidence is still required.
Proof and commerce remain separate.
REPORT

echo
echo "============================================================"
echo " OMNIPULSE REPAIR RESULT"
echo "============================================================"
echo "APP=$APP"
echo "LOCAL_HTTP=$HTTP_CODE"
echo "CONTENT_OK=$CONTENT_OK"
echo "EXISTING_TUNNEL=$TUNNEL_PROCESS"
echo "EXISTING_TUNNEL_8787=$TUNNEL_8787"
echo "PUBLIC_URL=$PUBLIC_URL"
echo "PUBLIC_HTTP=$PUBLIC_CODE"
echo "PUBLIC_OK=$PUBLIC_OK"
echo
echo "REPORT=$OUT/STATUS.md"
echo
echo "FINAL_DECISION=$FINAL_DECISION"
echo "PRODUCTION_UNLOCK=0"
echo "============================================================"

