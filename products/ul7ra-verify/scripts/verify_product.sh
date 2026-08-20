#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== UL7RA VERIFY PRODUCT TEST ==="

python3 tests/test_server.py

echo
echo "=== PRODUCT HASHES ==="

sha256sum \
    PRODUCT_CONTRACT.json \
    app/server.py \
    tests/test_server.py

echo
echo "=== RESULT ==="
echo "PRODUCT_TEST=PASS"
echo "DEPLOYMENT=NOT_PERFORMED"
echo "PAYMENTS=NOT_CONNECTED"
echo "REVENUE=0"
