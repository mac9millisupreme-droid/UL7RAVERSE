#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

SITE="ul7raverse-site"
WORK="$HOME/$SITE"
BRANCH="gh-pages"
REPO=""
URL=""

echo "=== UL7RAVERSE FREE PUBLIC LAUNCH ==="

command -v gh >/dev/null 2>&1 || {
  echo "ERROR=GitHub_CLI_MISSING"
  exit 1
}

command -v git >/dev/null 2>&1 || {
  echo "ERROR=GIT_MISSING"
  exit 1
}

gh auth status >/dev/null 2>&1 || {
  echo "ERROR=GITHUB_NOT_AUTHENTICATED"
  echo "Run: gh auth login"
  exit 1
}

USER="$(gh api user --jq '.login')"
REPO="$USER/$SITE"
URL="https://$USER.github.io/$SITE/"

rm -rf "$WORK"
mkdir -p "$WORK"

cat > "$WORK/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>UL7RAVERSE — Prove It</title>
<meta name="description" content="UL7RAVERSE — sovereign intelligence infrastructure built around proof, continuous verification and human control.">
<style>
*{box-sizing:border-box}
body{margin:0;background:#080808;color:#f5f5f5;font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
main{max-width:980px;margin:auto;padding:70px 22px}
.kicker{letter-spacing:.18em;text-transform:uppercase;font-size:12px;opacity:.65}
h1{font-size:clamp(48px,10vw,96px);line-height:.9;margin:18px 0}
h2{font-size:32px;margin-top:70px}
p{font-size:19px;line-height:1.65;color:#cfcfcf}
.hero p{max-width:720px}
.badge{display:inline-block;border:1px solid #444;border-radius:999px;padding:8px 13px;margin:6px 5px 0 0;font-size:13px}
.cta{display:inline-block;margin-top:28px;padding:16px 23px;border-radius:8px;background:#fff;color:#000;text-decoration:none;font-weight:800}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:16px}
.card{border:1px solid #292929;border-radius:14px;padding:24px;background:#101010}
.price{font-size:42px;font-weight:800}
small{color:#999}
footer{margin-top:90px;border-top:1px solid #292929;padding-top:25px;color:#777}
</style>
</head>
<body>
<main>
<section class="hero">
<div class="kicker">UL7RAVERSE</div>
<h1>PROVE<br>IT.</h1>
<p>
Sovereign intelligence infrastructure built around proof, continuous
verification, adversarial testing and human control.
</p>

<div>
<span class="badge">Privacy First</span>
<span class="badge">Cloud Optional</span>
<span class="badge">Continuous Verification</span>
<span class="badge">Fail Closed</span>
</div>

<a class="cta" href="#membership">Explore UL7RAPASS</a>
</section>

<section id="membership">
<h2>UL7RAPASS</h2>
<div class="card">
<div class="kicker">Founding Membership</div>
<div class="price">$500 CAD</div>
<p>12-month membership access to the UL7RAVERSE proof and verification ecosystem.</p>

<div class="grid">
<div class="card">
<strong>UL7RAPROOF</strong>
<p>Continuous verification and proof-state reporting.</p>
</div>
<div class="card">
<strong>LUCI</strong>
<p>LUCI Diagnostic, LUCI Test and adversarial verification.</p>
</div>
<div class="card">
<strong>PURPLE TEAM</strong>
<p>Adversarial testing designed to challenge assumptions before trust.</p>
</div>
<div class="card">
<strong>MEMBER NODE</strong>
<p>Member Node Access and participation in the evolving ecosystem.</p>
</div>
</div>

<p><strong>1,500 membership units planned.</strong></p>

<!-- Add your verified payment URL below when ready. -->
<a class="cta" href="#contact">Request Membership Access</a>
</div>
</section>

<section>
<h2>The principle</h2>
<p>
The system does not ask you to trust a claim simply because it was made.
It asks for evidence. Unknown remains unknown. Unverified never becomes
verified by assertion. Commerce and proof remain separate.
</p>
</section>

<section id="contact">
<h2>Start here</h2>
<p>
UL7RAPASS is being released as a controlled membership program.
Contact the operator for current enrollment and verified payment instructions.
</p>
<p><strong>MAC9 / UL7RAVERSE</strong></p>
</section>

<footer>
UL7RAVERSE — Where the cloud is optional. Trust is not.
</footer>
</main>
</body>
</html>
HTML

cd "$WORK"
git init -q
git checkout -q -b "$BRANCH"
git add index.html
git -c user.name="UL7RAVERSE Publisher" \
    -c user.email="ul7raverse@users.noreply.github.com" \
    commit -q -m "Launch UL7RAVERSE public sales site"

if gh repo view "$REPO" >/dev/null 2>&1; then
  echo "REPOSITORY=EXISTS"
else
  gh repo create "$REPO" --public --description "UL7RAVERSE public sales site" >/dev/null
  echo "REPOSITORY=CREATED"
fi

git remote add origin "https://github.com/$REPO.git" 2>/dev/null || true
git push -u origin "$BRANCH" --force >/dev/null

gh api \
  --method POST \
  "/repos/$REPO/pages" \
  -f "source[branch]=$BRANCH" \
  -f "source[path]=/" >/dev/null 2>&1 || true

echo
echo "=== PUBLISHED ==="
echo "REPOSITORY=https://github.com/$REPO"
echo "PUBLIC_URL=$URL"
echo

sleep 8

STATUS="$(curl -L -s -o /dev/null -w '%{http_code}' \
  --connect-timeout 10 --max-time 20 "$URL" || true)"

echo "PUBLIC_HTTP_STATUS=$STATUS"

if [ "$STATUS" = "200" ]; then
  echo "SITE_OK=1"
  echo "FINAL_DECISION=PASS"
else
  echo "SITE_OK=0"
  echo "FINAL_DECISION=TEST"
  echo "GitHub Pages can require several minutes to activate."
fi

echo "EVIDENCE_PATH=$WORK"
