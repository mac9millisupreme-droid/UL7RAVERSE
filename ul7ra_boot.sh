#!/data/data/com.termux/files/usr/bin/bash

set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || exit 1

echo "======================================"
echo " UL7RA4ORGE BOOTLOADER"
echo "======================================"
echo "ROOT: $ROOT"
echo "TIME: $(date -Iseconds)"
echo

echo "[1] GIT"
git rev-parse --show-toplevel 2>/dev/null || echo "Git: unavailable"
git rev-parse --short HEAD 2>/dev/null || echo "HEAD: unavailable"
git status --short --branch 2>/dev/null || true
echo

echo "[2] ENVIRONMENT"
command -v python || true
python --version 2>/dev/null || true
command -v git || true
command -v cloudflared || true
echo

echo "[3] EXISTING EXECUTORS"
find "$ROOT" -maxdepth 4 -type f \
  \( -name "*.sh" -o -name "*runner*" -o -name "*boot*" -o -name "*main*" \) \
  -not -path "$ROOT/.git/*" \
  2>/dev/null | sort | head -100
echo

echo "[4] EXISTING UL7RA COMPONENTS"
find "$ROOT" -maxdepth 4 -type f \
  -not -path "$ROOT/.git/*" \
  2>/dev/null |
  grep -Ei 'ul7ra|apex|trinity|proof|forge|bridge|stack|cloudflare' |
  head -150
echo

echo "[5] TEST DISCOVERY"
find "$ROOT" -maxdepth 5 -type f \
  \( -name "test_*.py" -o -name "*_test.py" -o -name "*.sh" \) \
  -not -path "$ROOT/.git/*" \
  2>/dev/null | sort | head -150
echo

echo "[6] BOOTLOADER STATE"
echo "BOOTLOADER=CREATED"
echo "MODE=DISCOVERY_ONLY"
echo "NO_ARCHITECTURE_REPLACEMENT=TRUE"
echo "NO_DESTRUCTIVE_ACTIONS=TRUE"
echo
echo "NEXT ACTION: inspect discovered implementation"
echo "======================================"
