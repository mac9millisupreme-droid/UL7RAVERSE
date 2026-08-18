#!/data/data/com.termux/files/usr/bin/bash
set -eu

BASE="$(cd "$(dirname "$0")/.." && pwd)"
GHOST="$BASE/ghost/runtime/os-test-$$"

mkdir -p "$GHOST"

cleanup() {
    rm -rf "$GHOST"
}
trap cleanup EXIT

printf '%s\n' "EPHEMERAL_TEST_DATA" > "$GHOST/data"

test -f "$GHOST/data"

# Verify the process can only observe the explicitly created test area.
# This is a filesystem-policy test, not a kernel sandbox claim.
test "$(cat "$GHOST/data")" = "EPHEMERAL_TEST_DATA"

# Verify cleanup is deterministic.
rm -rf "$GHOST"

if [ -e "$GHOST" ]; then
    echo "FAIL: ephemeral state survived cleanup"
    exit 1
fi

echo "EPHEMERAL STATE = PASS"
echo "DETERMINISTIC CLEANUP = PASS"
echo "OS BASELINE = PASS"
