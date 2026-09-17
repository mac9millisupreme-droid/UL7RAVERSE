#!/usr/bin/env bash
set -euo pipefail
cargo fmt --check
cargo test --all-targets
cargo run --quiet --bin halo9-demo | tee /tmp/halo9-demo.out
grep -q 'action_allowed=false' /tmp/halo9-demo.out
grep -q 'production_unlock=BLOCKED' /tmp/halo9-demo.out
printf '\nHALO9 V1 VERIFICATION: PASS (state-machine tests only; production crypto intentionally BLOCKED)\n'
