#!/data/data/com.termux/files/usr/bin/bash
set -u
cargo fmt --check || exit 1
cargo test --all-targets || exit 1
cargo run || exit 1
printf '\nHALO9_BRIDGE_GATE=VERIFIED\n'
printf 'PRODUCTION_CRYPTO=NOT_CONFIGURED\n'
printf 'PRODUCTION_UNLOCK=BLOCKED\n'
