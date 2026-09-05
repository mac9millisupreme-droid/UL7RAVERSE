#!/data/data/com.termux/files/usr/bin/bash
set -u

ROOT="$HOME/UL7RAVERSE"
cd "$ROOT" || exit 1

echo "========================================"
echo " UL7RA TERMUX SENTINEL"
echo "========================================"
echo "TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "ROOT=$ROOT"
echo

pass=0
block=0

check_exec() {
    local name="$1"
    local cmd="$2"

    if command -v "$cmd" >/dev/null 2>&1; then
        echo "$name=PASS"
        pass=$((pass+1))
    else
        echo "$name=BLOCKED"
        block=$((block+1))
    fi
}

echo "=== TOOLCHAIN ==="
check_exec PYTHON python3
check_exec GIT git
check_exec GH gh
check_exec CLOUDFLARED cloudflared
check_exec CARGO cargo

echo
echo "=== REPOSITORY ==="

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "GIT_REPO=PASS"
    echo "HEAD=$(git rev-parse HEAD)"
    echo "BRANCH=$(git branch --show-current)"
    pass=$((pass+1))
else
    echo "GIT_REPO=BLOCKED"
    block=$((block+1))
fi

echo
echo "=== CORE FILES ==="

files=(
    "ul7ra_boot.sh"
    "lucideploy/run_final_gate.sh"
    "products/ul7ra-verify/app/server.py"
    "products/ul7ra-verify/PRODUCT_CONTRACT.json"
    "UL7RAFORGE/v10/ul7rastack/assurance/continuous_gate_loop.sh"
)

for f in "${files[@]}"; do
    if [ -f "$f" ]; then
        echo "FILE=$f PASS"
        pass=$((pass+1))
    else
        echo "FILE=$f BLOCKED"
        block=$((block+1))
    fi
done

echo
echo "=== LOCAL VERIFY ==="

LOCAL_RESPONSE="$(curl -sS --max-time 3 \
    http://127.0.0.1:8787/ 2>/dev/null || true)"

if [ -n "$LOCAL_RESPONSE" ]; then
    echo "LOCAL_HTTP=PASS"
    echo "$LOCAL_RESPONSE"
    pass=$((pass+1))
else
    echo "LOCAL_HTTP=BLOCKED"
    block=$((block+1))
fi

echo
echo "=== CLOUDFLARED PROCESS ==="

if pgrep -f 'cloudflared.*tunnel' >/dev/null 2>&1; then
    echo "CLOUDFLARED_TUNNEL=PASS"
    pass=$((pass+1))
else
    echo "CLOUDFLARED_TUNNEL=BLOCKED"
    block=$((block+1))
fi

echo
echo "=== NAMED TUNNEL ==="

if command -v cloudflared >/dev/null 2>&1; then
    if cloudflared tunnel info ul7ra-verify 2>/dev/null |
        grep -q 'CONNECTOR ID'; then
        echo "NAMED_TUNNEL=PASS"
        pass=$((pass+1))
    else
        echo "NAMED_TUNNEL=BLOCKED"
        block=$((block+1))
    fi
fi

echo
echo "=== WORKTREE SUMMARY ==="

git status --porcelain=v1 |
awk '
{
    x=substr($0,1,2)
    if (x=="??") u++
    else if (x ~ /D/) d++
    else if (x ~ /M/) m++
    else if (x ~ /A/) a++
    else if (x ~ /R/) r++
    else o++
}
END {
    print "MODIFIED="m+0
    print "DELETED="d+0
    print "ADDED="a+0
    print "RENAMED="r+0
    print "UNTRACKED="u+0
    print "OTHER="o+0
}'

echo
echo "=== LIGHTWEIGHT SOURCE COUNT ==="

SOURCE_COUNT=$(find UL7RAFORGE/v10 -type f \
    ! -path '*/target/*' \
    ! -path '*/.git/*' \
    2>/dev/null | wc -l)

echo "SOURCE_FILES=$SOURCE_COUNT"

echo
echo "========================================"
echo " PASS=$pass"
echo " BLOCKED=$block"
echo "========================================"

if [ "$block" -eq 0 ]; then
    echo "SENTINEL=PASS"
else
    echo "SENTINEL=BLOCKED"
fi
