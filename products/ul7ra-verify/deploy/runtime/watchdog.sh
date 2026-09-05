#!/data/data/com.termux/files/usr/bin/bash

ROOT="$HOME/UL7RAVERSE"
PRODUCT="$ROOT/products/ul7ra-verify"
RUNTIME="$PRODUCT/deploy/runtime"

PORT=8787
CONFIG="$HOME/.cloudflared/config.yml"

SERVER_LOG="$RUNTIME/server.log"
TUNNEL_LOG="$RUNTIME/cloudflared.log"

SERVER_PID="$RUNTIME/server.pid"
TUNNEL_PID="$RUNTIME/cloudflared.pid"
WATCHDOG_LOG="$RUNTIME/watchdog.log"

mkdir -p "$RUNTIME"

log() {
    echo "$(date -Iseconds) $*" >> "$WATCHDOG_LOG"
}

start_origin() {
    if curl -4 -fsS --connect-timeout 2 --max-time 3 \
        "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
        return 0
    fi

    log "ORIGIN_DOWN restarting"

    pkill -f "$PRODUCT/app/server.py" 2>/dev/null || true

    nohup python3 "$PRODUCT/app/server.py" \
        >>"$SERVER_LOG" 2>&1 &

    echo $! > "$SERVER_PID"

    sleep 1
}

start_tunnel() {
    if cloudflared tunnel info ul7ra-verify 2>/dev/null |
        grep -q "CONNECTOR ID"; then
        return 0
    fi

    log "NAMED_TUNNEL_DOWN restarting"

    pkill -f "cloudflared tunnel --config $CONFIG run ul7ra-verify" \
        2>/dev/null || true

    nohup cloudflared tunnel \
        --config "$CONFIG" \
        run ul7ra-verify \
        >>"$TUNNEL_LOG" 2>&1 &

    echo $! > "$TUNNEL_PID"

    sleep 3
}

# Kill obsolete Quick Tunnel.
pkill -f "cloudflared tunnel --url http://127.0.0.1:8787" \
    2>/dev/null || true

log "WATCHDOG_STARTED"

while true; do
    start_origin
    start_tunnel

    if curl -4 -fsS --connect-timeout 3 --max-time 5 \
        https://omnilucient.com/ >/dev/null 2>&1; then
        log "PUBLIC_ROUTE_PASS"
    else
        log "PUBLIC_ROUTE_NOT_PROVEN"
    fi

    sleep 15
done
