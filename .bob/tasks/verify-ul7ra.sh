#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "=== UL7RAVERSE BOB VALIDATION ==="

cd "$(git rev-parse --show-toplevel)"

echo
echo "=== REPOSITORY ==="
git branch --show-current
git rev-parse --verify HEAD

echo
echo "=== P52 VALIDATION ==="

cd UL7RAFORGE/v10/ul7rabridge

for t in \
tests/canada_only_regression.sh \
tests/cheetah_regression.sh \
tests/ghost_regression.sh \
tests/live_status_regression.sh \
tests/security_assurance.sh \
tests/tamper_detection.sh
do
    echo "--- $t"
    bash "$t"
done

echo
echo "=== BOB VALIDATION COMPLETE ==="
echo "STATUS=PASS"
