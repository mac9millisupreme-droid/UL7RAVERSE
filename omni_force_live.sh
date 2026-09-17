#!/data/data/com.termux/files/usr/bin/bash
set -u

ROOT="$HOME/UL7RAVERSE"
BASE="$ROOT/verification_artifacts/omnipulse"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$BASE/force-live/$TS"
APP="$OUT/app"
PORT=8899

mkdir -p "$APP"

echo "============================================================"
echo " OMNIPULSE × UL7RAVERSE × MAC9RECORDS"
echo " FORCE LIVE — FRESH RUNTIME"
echo "============================================================"
echo "TIMESTAMP=$TS"
echo

# ------------------------------------------------------------
# CREATE FRESH PUBLIC FRONT DOOR
# ------------------------------------------------------------
cat > "$APP/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>OmniPulse — Find Your Fair</title>
<meta name="description" content="Find your Fair with OmniPulse. Explore UL7RAVERSE and MAC9RECORDS.">
<style>
*{box-sizing:border-box}
body{margin:0;background:#080808;color:#fff;font-family:system-ui,sans-serif}
main{max-width:720px;margin:auto;padding:18px}
.hero{padding:28px 20px;border:1px solid #333;border-radius:24px;background:#151515}
.kicker{font-size:12px;letter-spacing:2px;color:#aaa}
h1{font-size:44px;line-height:.95;margin:12px 0}
h2{font-size:23px}
p{line-height:1.55;color:#ccc}
.cta{display:block;background:#fff;color:#000;text-align:center;text-decoration:none;padding:18px;border-radius:14px;font-weight:900;margin:22px 0}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:10px}
.card{padding:16px;border:1px solid #333;border-radius:15px;background:#101010}
.small{font-size:11px;letter-spacing:1px;color:#999}
.brand{margin-top:14px;padding:20px;border:1px solid #333;border-radius:18px}
.brand b{font-size:22px}
.footer{margin-top:22px;padding-top:16px;border-top:1px solid #333;font-size:12px;color:#888}
</style>
</head>
<body>
<main>

<section class="hero">
<div class="kicker">OMNIPULSE × UL7RAVERSE × MAC9RECORDS</div>

<h1>🎡 FIND YOUR FAIR</h1>

<p>
Not sure where to start?
<strong>OmniPulse builds your Fair.</strong>
</p>

<div class="grid">
<div class="card">🔥<br><b>Can’t Miss</b></div>
<div class="card">🍔<br><b>Best Eats</b></div>
<div class="card">🎵<br><b>What’s On</b></div>
<div class="card">👨‍👩‍👧<br><b>Family</b></div>
<div class="card">💰<br><b>Best Value</b></div>
<div class="card">⚠️<br><b>Know Before You Go</b></div>
</div>

<a class="cta" href="#build">SCAN → BUILD YOUR FAIR</a>
</section>

<section id="build" class="brand">
<div class="small">LIVE EXPERIENCE</div>
<h2>Build your Fair around you.</h2>
<p>
Choose your time, group, interests and budget.
Discover what matters to you instead of wandering blindly.
</p>
</section>

<section class="brand">
<div class="small">PROOF LAYER</div>
<b>UL7RAVERSE</b>
<p>
Proof-first sovereign intelligence infrastructure.
Where the cloud is optional. Trust is not.
</p>
</section>

<section class="brand">
<div class="small">CREATIVE LAYER</div>
<b>MAC9RECORDS</b>
<p>
Music, culture, stories and original creative work from MAC9.
</p>
</section>

<section class="brand">
<div class="small">THE LOOP</div>
<b>Experience → Signal → Proof → Share</b>
<p>
OmniPulse helps people discover and experience.
UL7RAVERSE provides the proof architecture.
MAC9RECORDS provides the creative identity.
</p>
</section>

<div class="footer">
OmniPulse is presented as an independent digital companion.
No Western Fair endorsement or partnership is claimed without actual authorization.
Visitor signals are not automatically verified claims.
</div>

</main>
</body>
</html>
HTML

# ------------------------------------------------------------
# HASH EXACT SOURCE
# ------------------------------------------------------------
sha256sum "$APP/index.html" > "$OUT/source.sha256"

# ------------------------------------------------------------
# KILL ONLY OUR NEW TEST PORT
# ------------------------------------------------------------
pkill -f "python.*http.server $PORT" 2>/dev/null || true
sleep 1

# ------------------------------------------------------------
# SERVE FRESH DIRECTORY
# ------------------------------------------------------------
(
  cd "$APP"
  exec python -m http.server "$PORT" --bind 127.0.0.1
) > "$OUT/server.log" 2>&1 &

SERVER_PID=$!
echo "$SERVER_PID" > "$OUT/server.pid"

sleep 2

# ------------------------------------------------------------
# FETCH EXACT LIVE RESPONSE
# ------------------------------------------------------------
curl -fsS "http://127.0.0.1:$PORT/" > "$OUT/live.html" 2>/dev/null || true

HTTP_CODE="$(
  curl -s -o /dev/null -w '%{http_code}' \
  "http://127.0.0.1:$PORT/" 2>/dev/null || echo 000
)"

# ------------------------------------------------------------
# EXACT CONTENT TEST
# ------------------------------------------------------------
OMNIPULSE=0
UL7RAVERSE=0
MAC9RECORDS=0
FIND_FAIR=0
BUILD_FAIR=0

grep -qi "OMNIPULSE" "$OUT/live.html" && OMNIPULSE=1
grep -qi "UL7RAVERSE" "$OUT/live.html" && UL7RAVERSE=1
grep -qi "MAC9RECORDS" "$OUT/live.html" && MAC9RECORDS=1
grep -qi "FIND YOUR FAIR" "$OUT/live.html" && FIND_FAIR=1
grep -qi "BUILD YOUR FAIR" "$OUT/live.html" && BUILD_FAIR=1

if [ "$HTTP_CODE" = "200" ] &&
   [ "$OMNIPULSE" = "1" ] &&
   [ "$UL7RAVERSE" = "1" ] &&
   [ "$MAC9RECORDS" = "1" ] &&
   [ "$FIND_FAIR" = "1" ] &&
   [ "$BUILD_FAIR" = "1" ]; then
  CONTENT_OK=1
else
  CONTENT_OK=0
fi

# ------------------------------------------------------------
# VERIFY LIVE RESPONSE IS ACTUALLY OUR NEW FILE
# ------------------------------------------------------------
LIVE_HASH="$(sha256sum "$OUT/live.html" 2>/dev/null | awk '{print $1}')"
SOURCE_HASH="$(awk '{print $1}' "$OUT/source.sha256")"

if [ "$LIVE_HASH" = "$SOURCE_HASH" ]; then
  BYTE_MATCH=1
else
  BYTE_MATCH=0
fi

echo "LOCAL_PORT=$PORT"
echo "LOCAL_HTTP=$HTTP_CODE"
echo "OMNIPULSE=$OMNIPULSE"
echo "UL7RAVERSE=$UL7RAVERSE"
echo "MAC9RECORDS=$MAC9RECORDS"
echo "FIND_YOUR_FAIR=$FIND_FAIR"
echo "BUILD_YOUR_FAIR=$BUILD_FAIR"
echo "CONTENT_OK=$CONTENT_OK"
echo "BYTE_MATCH=$BYTE_MATCH"

# ------------------------------------------------------------
# CLOUDFLARE CONTROLLED PUBLIC TEST
# ------------------------------------------------------------
PUBLIC_URL=""

if [ "$CONTENT_OK" = "1" ] &&
   [ "$BYTE_MATCH" = "1" ] &&
   command -v cloudflared >/dev/null 2>&1; then

  echo
  echo "STARTING CONTROLLED PUBLIC TUNNEL..."

  nohup cloudflared tunnel --url "http://127.0.0.1:$PORT" \
    > "$OUT/cloudflare.log" 2>&1 &

  CF_PID=$!
  echo "$CF_PID" > "$OUT/cloudflare.pid"

  for i in $(seq 1 30); do
    sleep 1

    PUBLIC_URL="$(
      grep -Eo 'https://[-a-zA-Z0-9]+\.trycloudflare\.com' \
      "$OUT/cloudflare.log" 2>/dev/null | head -1 || true
    )"

    [ -n "$PUBLIC_URL" ] && break
  done
fi

PUBLIC_HTTP=000
PUBLIC_OK=0

if [ -n "$PUBLIC_URL" ]; then

  curl -L -fsS "$PUBLIC_URL/" \
    > "$OUT/public.html" 2>/dev/null || true

  PUBLIC_HTTP="$(
    curl -L -s -o /dev/null -w '%{http_code}' \
    "$PUBLIC_URL/" 2>/dev/null || echo 000
  )"

  P1=0
  P2=0
  P3=0

  grep -qi "OMNIPULSE" "$OUT/public.html" && P1=1
  grep -qi "UL7RAVERSE" "$OUT/public.html" && P2=1
  grep -qi "MAC9RECORDS" "$OUT/public.html" && P3=1

  if [ "$PUBLIC_HTTP" = "200" ] &&
     [ "$P1" = "1" ] &&
     [ "$P2" = "1" ] &&
     [ "$P3" = "1" ]; then
    PUBLIC_OK=1
  fi
fi

# ------------------------------------------------------------
# GOVERNANCE
# ------------------------------------------------------------
if [ "$CONTENT_OK" = "1" ] && [ "$BYTE_MATCH" = "1" ]; then
  FINAL_DECISION="TEST"
else
  FINAL_DECISION="BLOCKED"
fi

PRODUCTION_UNLOCK=0
CANONICAL_PROMOTION=0
PROOF_OK=0
REAL_VISITOR=0
REAL_VENDOR=0
PAYMENT_VERIFIED=0
VERIFIED_REVENUE_CAD=0

# ------------------------------------------------------------
# REPORT
# ------------------------------------------------------------
cat > "$OUT/FINAL_STATUS.md" <<REPORT
# OmniPulse × UL7RAVERSE × MAC9RECORDS

TIMESTAMP=$TS

## Exact Runtime

APP=$APP
PORT=$PORT
HTTP_CODE=$HTTP_CODE
BYTE_MATCH=$BYTE_MATCH

## Brand Validation

OMNIPULSE=$OMNIPULSE
UL7RAVERSE=$UL7RAVERSE
MAC9RECORDS=$MAC9RECORDS
FIND_YOUR_FAIR=$FIND_FAIR
BUILD_YOUR_FAIR=$BUILD_FAIR
CONTENT_OK=$CONTENT_OK

## Public Reachability

PUBLIC_URL=$PUBLIC_URL
PUBLIC_HTTP=$PUBLIC_HTTP
PUBLIC_OK=$PUBLIC_OK

## Governance

REAL_VISITOR=$REAL_VISITOR
REAL_VENDOR=$REAL_VENDOR
PAYMENT_VERIFIED=$PAYMENT_VERIFIED
VERIFIED_REVENUE_CAD=$VERIFIED_REVENUE_CAD
PROOF_OK=$PROOF_OK
PRODUCTION_UNLOCK=$PRODUCTION_UNLOCK
CANONICAL_PROMOTION=$CANONICAL_PROMOTION

FINAL_DECISION=$FINAL_DECISION

## Architecture

OMNIPULSE=DISCOVERY_AND_EXPERIENCE
UL7RAVERSE=PROOF_AND_TRUST_LAYER
MAC9RECORDS=CREATIVE_AND_CULTURAL_LAYER

## Rule

A successful local test proves local serving.
A successful public test proves reachability.
Neither proves endorsement.
Neither proves verified claims.
Neither proves revenue.
No proof -> trusted action.
No payment -> revenue claim.
No real visitor -> production promotion remains blocked.
REPORT

# ------------------------------------------------------------
# FINAL OUTPUT
# ------------------------------------------------------------
echo
echo "============================================================"
echo " OMNIPULSE × UL7RAVERSE × MAC9RECORDS"
echo " FORCE LIVE RESULT"
echo "============================================================"
echo
echo "LOCAL_URL=http://127.0.0.1:$PORT/"
echo "PUBLIC_URL=$PUBLIC_URL"
echo
echo "LOCAL_HTTP=$HTTP_CODE"
echo "BYTE_MATCH=$BYTE_MATCH"
echo "CONTENT_OK=$CONTENT_OK"
echo "PUBLIC_HTTP=$PUBLIC_HTTP"
echo "PUBLIC_OK=$PUBLIC_OK"
echo
echo "REPORT=$OUT/FINAL_STATUS.md"
echo
echo "FINAL_DECISION=$FINAL_DECISION"
echo "PRODUCTION_UNLOCK=$PRODUCTION_UNLOCK"
echo "============================================================"
