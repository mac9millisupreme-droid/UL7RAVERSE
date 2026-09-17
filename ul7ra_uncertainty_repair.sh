#!/usr/bin/env bash
# UL7RA Uncertainty Test Harness Repair
set -u
cd ~/UL7RAVERSE

FILE="racing/tests/test_uncertainty_propagation.py"

echo "[0] Inspect current file..."
head -20 "$FILE"

echo
echo "[1] Add missing pytest import if absent..."
if grep -q '^import pytest' "$FILE"; then
    echo "import pytest already present"
else
    # Insert after the sys.path line or at the top if no imports
    if grep -q '^import sys' "$FILE"; then
        # Insert after the last ^import line
        sed -i '/^import /a import pytest' "$FILE"
    else
        sed -i '1i import pytest' "$FILE"
    fi
    echo "import pytest added"
fi

echo
echo "[2] Verify file..."
head -20 "$FILE"

echo
echo "[3] Targeted test..."
python -m pytest -q "$FILE" -vv --tb=long
TARGET=$?

echo
echo "[4] Full racing suite..."
python -m pytest -q racing/tests -vv --tb=long
FULL=$?

echo
echo "[5] AIL regression..."
python -m pytest -q \
  racing/tests/test_ail_adversarial.py \
  racing/tests/test_ail_decision.py \
  racing/tests/test_ail_invariants.py \
  racing/tests/test_ail_provenance.py \
  racing/tests/test_ail_replay.py \
  racing/tests/test_ail_shadow.py \
  racing/tests/test_ail_temporal.py \
  -vv --tb=long
AIL=$?

echo
echo "[6] Determinism check (3 runs)..."
RUN1=1; RUN2=1; RUN3=1
python -m pytest -q racing/tests > /dev/null 2>&1
RUN1=$?
python -m pytest -q racing/tests > /dev/null 2>&1
RUN2=$?
python -m pytest -q racing/tests > /dev/null 2>&1
RUN3=$?
DET=1
if [ "$FULL" -eq 0 ] && [ "$RUN1" -eq 0 ] && [ "$RUN2" -eq 0 ] && [ "$RUN3" -eq 0 ]; then
    DET=0
fi
echo "Determinism runs: $RUN1 $RUN2 $RUN3"
echo "[RESULT] DETERMINISM=$DET"

echo
echo "[7] Git audit..."
git status --short
git diff --stat
git diff -- "$FILE"

echo
echo "[8] Production-code protection check..."
if git diff --name-only | grep -q '^racing/uncertainty_propagation.py$'; then
    echo "WARNING: production uncertainty code was modified."
    PROD=1
else
    echo "Production uncertainty code unchanged."
    PROD=0
fi

echo
echo "============================================="
echo " UL7RA FINAL STATUS"
echo "============================================="
echo "TARGETED_UNCERTAINTY: $TARGET"
echo "FULL_RACING:          $FULL"
echo "AIL_REGRESSION:       $AIL"
echo "DETERMINISM:          $DET"
echo "PRODUCTION_CHANGED:   $PROD"
if [ "$TARGET" -eq 0 ] && [ "$FULL" -eq 0 ] && [ "$AIL" -eq 0 ] && [ "$DET" -eq 0 ] && [ "$PROD" -eq 0 ]; then
    echo "OVERALL: PASS"
    exit 0
else
    echo "OVERALL: FAIL"
    exit 1
fi
