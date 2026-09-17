#!/data/data/com.termux/files/usr/bin/bash
set +e
echo "=== UL7RA RACING RECON ==="
echo "ROOT=$(pwd)"
echo "BRANCH=$(git branch --show-current)"
echo "HEAD=$(git rev-parse HEAD)"
echo
echo "=== RACING FILES ==="
find racing -maxdepth 5 -type f -print 2>/dev/null | sort
echo
echo "=== RACING TESTS ==="
python -m pytest -q racing/tests
RACING_RC=$?
echo
echo "=== EXISTING REGRESSION ==="
python -m pytest -q UL7RAFORGE/v06/tests lucideploy/tests products/ul7ra-verify/tests
REG_RC=$?
echo
echo "=== READINESS / GATES ==="
grep -RniE 'PRODUCTION_READINESS|production_gate|production.*LOCKED|RELEASE_GATE|REQUIRED =' \
UL7RAFORGE lucideploy products --include='*.py' 2>/dev/null | head -300
echo
echo "=== VERISCORE ==="
find UL7RAFORGE -type f \( -iname '*veriscore*' -o -iname '*score*' \) \
-print 2>/dev/null | sort | head -200
echo
echo "=== EVIDENCE / PROOF ==="
find UL7RAFORGE -type f \( -iname '*evidence*' -o -iname '*ledger*' -o -iname '*proof*' -o -iname '*attest*' \) \
-print 2>/dev/null | sort | head -200
echo
echo "=== SECURITY / PROVENANCE ==="
find UL7RAFORGE -type f \( -iname '*security*' -o -iname '*purple*' -o -iname '*provenance*' -o -iname '*rollback*' \) \
-print 2>/dev/null | sort | head -200
echo
echo "=== TRINITY ==="
for f in UL7RAFORGE/trinity/*.py UL7RAFORGE/v09/trinity/*.py; do
  [ -f "$f" ] || continue
  echo "--- $f ---"
  sed -n '1,220p' "$f"
done
echo
echo "=== GIT STATUS ==="
git status --short
echo
echo "=== FINAL ==="
echo "RACING_TEST_RC=$RACING_RC"
echo "REGRESSION_TEST_RC=$REG_RC"
[ "$RACING_RC" -eq 0 ] && [ "$REG_RC" -eq 0 ] && echo "STATUS=PASS_RECON_TESTS" || echo "STATUS=BLOCKED_OR_FAILED"
echo "DNS=UNCHANGED"
echo "PRODUCTION=LOCKED"
