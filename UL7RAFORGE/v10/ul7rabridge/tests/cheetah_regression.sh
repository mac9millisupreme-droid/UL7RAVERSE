#!/data/data/com.termux/files/usr/bin/bash
set -e

BIN="./target/release/cheetah"

echo "[1] allowed direction"
"$BIN" "REGRESSION_TEST" >/dev/null

echo "[2] prohibited direction"
if CHEETAH_DIRECTION=EXTERNAL_TO_SOVEREIGN \
   "$BIN" "RETURN_TEST" >/dev/null 2>&1; then
    echo "FAIL: prohibited direction accepted"
    exit 1
fi

echo "[3] regression result"
echo "CHEETAH REGRESSION = PASS"
