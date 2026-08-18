#!/data/data/com.termux/files/usr/bin/bash
set -eu

STATUS="../ul7rastack/live/state/live_status.json"

python ../ul7rastack/verifier/src/verify.py "$STATUS"
