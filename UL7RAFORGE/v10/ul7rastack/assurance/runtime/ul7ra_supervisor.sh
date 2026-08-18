#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="$HOME/UL7RAVERSE/UL7RAFORGE"
cd "$ROOT"

LOG="v10/ul7rastack/assurance/runtime/supervisor.log"

while true; do
    {
        echo
        echo "========================================"
        echo "UL7RAFORGE SUPERVISOR"
        echo "UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "========================================"

        MAX_ITERATIONS=10 \
        ./v10/ul7rastack/assurance/continuous_gate_loop.sh

        rc=$?

        echo "LOOP_EXIT=$rc"
        echo "PRODUCTION=LOCKED"

        # A successful local gate does not mean production authorization.
        # Stop and preserve evidence for human/independent review.
        if [ "$rc" -eq 0 ]; then
            echo "STATE=RELEASE_GATE_ELIGIBLE"
            echo "SUPERVISOR=STOPPED_FOR_REVIEW"
            exit 0
        fi

        echo "STATE=BLOCKED_OR_FAILED"
        echo "RETRYING_AFTER=30"

    } >>"$LOG" 2>&1

    sleep 30
done
