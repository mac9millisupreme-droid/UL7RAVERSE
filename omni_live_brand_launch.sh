#!/data/data/com.termux/files/usr/bin/bash
set -u

ROOT="$HOME/UL7RAVERSE"
BASE="$ROOT/verification_artifacts/omnipulse"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$BASE/live-brand/$TS"
mkdir -p "$OUT"

echo "============================================================"
echo " OMNIPULSE × UL7RAVERSE × MAC9RECORDS"
echo " ONE-SCRIPT LIVE BRAND LAUNCH"
echo "============================================================"
echo "TIMESTAMP=$TS"
echo

# ------------------------------------------------------------
# FIND MOST RECENT OMNIPULSE BUILD
# ------------------------------------------------------------
APP="$(find "$BASE" -type f -path '*/app/index.html' 2>/dev/null \
  | sort | tail -1 | sed 's|/index.html$||')"

if [ -z "$APP" ]; then
  echo "FINAL_DECISION=BLOCKED"
  echo "REASON=NO_OMNIPULSE_APP_FOUND"
  exit 1
fi

ORIGINAL="$APP/index.html"
BACKUP="$APP/index_visitor_original.html"

echo "APP=$APP"

# ------------------------------------------------------------
# PRESERVE ORIGINAL VISITOR EXPERIENCE
# ------------------------------------------------------------
if [ ! -f "$BACKUP" ]; then
  cp "$ORIGINAL" "$BACKUP"
fi

# ------------------------------------------------------------
# BUILD INTEGRATED LIVE FRONT DOOR
# ------------------------------------------------------------
cat > "$APP/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>OmniPulse — Find Your Fair</title>
<meta name="description" content="OmniPulse helps you find your Fair while UL7RAVERSE and MAC9RECORDS build the proof, culture and creative layer underneath.">
<style>
*{box-sizing:border-box}
body{
 margin:0;
 background:#090909;
 color:#fff;
 font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
}
.wrap{max-width:760px;margin:auto;padding:18px}
.hero{
 padding:28px 18px 22px;
 border:1px solid #333;
 border-radius:22px;
 background:linear-gradient(180deg,#171717,#0d0d0d);
}
.kicker{font-size:12px;letter-spacing:2px;opacity:.65}
h1{font-size:42px;line-height:.95;margin:10px 0}
h2{margin:8px 0;font-size:22px}
p{line-height:1.5;color:#d2d2d2}
.cta{
 display:block;
 text-align:center;
 text-decoration:none;
 background:#fff;
 color:#000;
 padding:17px;
 border-radius:14px;
 font-weight:800;
 margin:18px 0;
}
.grid{
 display:grid;
 grid-template-columns:1fr 1fr;
 gap:10px;
 margin:16px 0;
}
.card{
 padding:15px;
 border:1px solid #333;
 border-radius:15px;
 background:#111;
}
.label{font-size:11px;letter-spacing:1.5px;opacity:.6}
.big{font-weight:800;margin-top:5px}
.brand{
 margin-top:14px;
 padding:18px;
 border:1px solid #333;
 border-radius:18px;
}
.brand strong{font-size:21px}
.brand p{margin-bottom:0}
.notice{
 font-size:12px;
 color:#aaa;
 border-top:1px solid #292929;
 margin-top:20px;
 padding-top:15px;
}
iframe{
 width:100%;
 min-height:900px;
 border:1px solid #333;
 border-radius:20px;
 margin-top:18px;
 background:#fff;
}
</style>
</head>
<body>
<div class="wrap">

<section class="hero">
<div class="kicker">OMNIPULSE × UL7RAVERSE × MAC9RECORDS</div>

<h1>🎡 FIND YOUR FAIR</h1>

<p>
Not sure where to start?
<strong>OmniPulse builds your Fair.</strong>
</p>

<div class="grid">
<div class="card"><div class="label">DISCOVER</div><div class="big">🔥 Can’t Miss</div></div>
<div class="card"><div class="label">EAT</div><div class="big">🍔 Best Eats</div></div>
<div class="card"><div class="label">EVENTS</div><div class="big">🎵 What’s On</div></div>
<div class="card"><div class="label">GROUPS</div><div class="big">👨‍👩‍👧 Family</div></div>
<div class="card"><div class="label">VALUE</div><div class="big">💰 Best Value</div></div>
<div class="card"><div class="label">SIGNAL</div><div class="big">⚠️ Know Before You Go</div></div>
</div>

<a class="cta" href="#build">SCAN → BUILD YOUR FAIR</a>
</section>

<section class="brand">
<div class="label">THE PROOF LAYER</div>
<strong>UL7RAVERSE</strong>
<p>
Proof-first sovereign intelligence infrastructure.
Where the cloud is optional. Trust is not.
</p>
</section>

<section class="brand">
<div class="label">THE CREATIVE LAYER</div>
<strong>MAC9RECORDS</strong>
<p>
Music, culture, stories and original creative work from MAC9.
</p>
</section>

<section class="brand">
<div class="label">THE LOOP</div>
<strong>Experience → Signal → Proof → Share</strong>
<p>
OmniPulse helps people experience the Fair.
UL7RAVERSE protects the evidence layer.
MAC9RECORDS gives the ecosystem a recognizable creative voice.
</p>
</section>

<div id="build"></div>

<iframe
 src="index_visitor_original.html"
 title="OmniPulse Find Your Fair">
</iframe>

<div class="notice">
OmniPulse is presented as an independent digital companion.
No endorsement, sponsorship or partnership is claimed unless separately established.
Visitor experience signals are not automatically verified claims.
</div>

</div>
</body>
</html>
HTML

# ------------------------------------------------------------
# STOP OLD SERVER ON 8787
# ------------------------------------------------------------
OLD_PIDS="$(ps -ef 2>/dev/null \
  | grep '[p]ython.*http.server 8787' \
  | awk '{print $2}' || true)"

for PID in $OLD_PIDS; do
  kill "$PID" 2>/dev/null || true
done

sleep 1

# ------------------------------------------------------------
# START CORRECT APP DIRECTORY
# ------------------------------------------------------------
cd "$APP"

nohup python -m http.server 8787 --bind 127.0.0.1 \
  > "$OUT/http.log" 2>&1 &

SERVER_PID=$!
echo "$SERVER_PID" > "$OUT/server.pid"

sleep 2

# ------------------------------------------------------------
# LOCAL VALIDATION
# ------------------------------------------------------------
curl -fsS http://127.0.0.1:8787/ > "$OUT/live.html" 2>/dev/null || true

HTTP_CODE="$(curl -s -o /dev/null -w '%{http_code}' \
  http://127.0.0.1:8787/ 2>/dev/null || echo 000)"

OMNIPULSE=0
UL7RAVERSE=0
MAC9RECORDS=0
BUILD=0

grep -qi "OMNIPULSE" "$OUT/live.html" && OMNIPULSE=1
grep -qi "UL7RAVERSE" "$OUT/live.html" && UL7RAVERSE=1
grep -qi "MAC9RECORDS" "$OUT/live.html" && MAC9RECORDS=1
grep -qi "BUILD YOUR FAIR" "$OUT/live.html" && BUILD=1

if [ "$HTTP_CODE" = "200" ] &&
   [ "$OMNIPULSE" = "1" ] &&
   [ "$UL7RAVERSE" = "1" ] &&
   [ "$MAC9RECORDS" = "1" ] &&
   [ "$BUILD" = "1" ]; then
  CONTENT_OK=1
else
  CONTENT_OK=0
fi

echo "LOCAL_HTTP=$HTTP_CODE"
echo "OMNIPULSE=$OMNIPULSE"
echo "UL7RAVERSE=$UL7RAVERSE"
echo "MAC9RECORDS=$MAC9RECORDS"
echo "BUILD_YOUR_FAIR=$BUILD"
echo "CONTENT_OK=$CONTENT_OK"

# ------------------------------------------------------------
# CONTROLLED CLOUDFLARE PUBLIC TEST
# ------------------------------------------------------------
PUBLIC_URL=""

if [ "$CONTENT_OK" = "1" ] && command -v cloudflared >/dev/null 2>&1; then

  echo
  echo "Starting controlled public test tunnel..."

  nohup cloudflared tunnel --url http://127.0.0.1:8787 \
    > "$OUT/cloudflare.log" 2>&1 &

  CF_PID=$!
  echo "$CF_PID" > "$OUT/cloudflare.pid"

  for i in $(seq 1 25); do
    sleep 1

    PUBLIC_URL="$(
      grep -Eo 'https://[-a-zA-Z0-9]+\.trycloudflare\.com' \
      "$OUT/cloudflare.log" 2>/dev/null \
      | head -1 || true
    )"

    [ -n "$PUBLIC_URL" ] && break
  done
fi

if [ -n "$PUBLIC_URL" ]; then
  PUBLIC_HTML="$OUT/public.html"

  PUBLIC_CODE="$(
    curl -L -s -o "$PUBLIC_HTML" \
    -w '%{http_code}' \
    "$PUBLIC_URL/" 2>/dev/null || echo 000
  )"

  P_OMNI=0
  P_UL7=0
  P_MAC9=0

  grep -qi "OMNIPULSE" "$PUBLIC_HTML" && P_OMNI=1
  grep -qi "UL7RAVERSE" "$PUBLIC_HTML" && P_UL7=1
  grep -qi "MAC9RECORDS" "$PUBLIC_HTML" && P_MAC9=1

  if [ "$PUBLIC_CODE" = "200" ] &&
     [ "$P_OMNI" = "1" ] &&
     [ "$P_UL7" = "1" ] &&
     [ "$P_MAC9" = "1" ]; then
    PUBLIC_OK=1
  else
    PUBLIC_OK=0
  fi
else
  PUBLIC_CODE=000
  PUBLIC_OK=0
fi

echo "PUBLIC_URL=$PUBLIC_URL"
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

# Public reachability is evidence, not production authorization.
PRODUCTION_UNLOCK=0
CANONICAL_PROMOTION=0
PROOF_OK=0
PAYMENT_VERIFIED=0
VERIFIED_REVENUE_CAD=0

# ------------------------------------------------------------
# EVIDENCE REPORT
# ------------------------------------------------------------
cat > "$OUT/STATUS.md" <<REPORT
# OmniPulse × UL7RAVERSE × MAC9RECORDS Live Status

TIMESTAMP=$TS

## Local

APP=$APP
SERVER_PID=$SERVER_PID
HTTP_CODE=$HTTP_CODE
OMNIPULSE=$OMNIPULSE
UL7RAVERSE=$UL7RAVERSE
MAC9RECORDS=$MAC9RECORDS
BUILD_YOUR_FAIR=$BUILD
CONTENT_OK=$CONTENT_OK

## Public Test

PUBLIC_URL=$PUBLIC_URL
PUBLIC_HTTP=$PUBLIC_CODE
PUBLIC_OK=$PUBLIC_OK

## Governance

REAL_VISITOR=0
REAL_VENDOR=0
PAYMENT_VERIFIED=$PAYMENT_VERIFIED
VERIFIED_REVENUE_CAD=$VERIFIED_REVENUE_CAD
PROOF_OK=$PROOF_OK
PRODUCTION_UNLOCK=$PRODUCTION_UNLOCK
CANONICAL_PROMOTION=$CANONICAL_PROMOTION

FINAL_DECISION=$FINAL_DECISION

## Promotion Architecture

OMNIPULSE=LIVE_TEST_SURFACE
UL7RAVERSE=BRAND_LAYER
MAC9RECORDS=CREATIVE_LAYER

## Governance Rule

Public reachability does not equal endorsement.
Public reachability does not equal verified proof.
Public reachability does not equal revenue.
No proof -> trusted action.
No payment -> revenue claim.
No real visitor -> production promotion remains blocked.

## Gate Message

FIND YOUR FAIR
SCAN → BUILD YOUR FAIR

OmniPulse is presented as an independent digital companion.
No Fair endorsement or partnership is claimed without actual authorization.
REPORT

# ------------------------------------------------------------
# FINAL
# ------------------------------------------------------------
echo
echo "============================================================"
echo " OMNIPULSE × UL7RAVERSE × MAC9RECORDS"
echo " LIVE TEST RESULT"
echo "============================================================"
echo
echo "LOCAL_URL=http://127.0.0.1:8787/"
echo "PUBLIC_URL=$PUBLIC_URL"
echo
echo "OMNIPULSE=$OMNIPULSE"
echo "UL7RAVERSE=$UL7RAVERSE"
echo "MAC9RECORDS=$MAC9RECORDS"
echo "CONTENT_OK=$CONTENT_OK"
echo "PUBLIC_OK=$PUBLIC_OK"
echo
echo "REPORT=$OUT/STATUS.md"
echo
echo "FINAL_DECISION=$FINAL_DECISION"
echo "PRODUCTION_UNLOCK=$PRODUCTION_UNLOCK"
echo "============================================================"
