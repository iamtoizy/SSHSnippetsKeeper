#!/bin/bash
SERVICES=(nginx redis-server postgresql)
MAX_RESTARTS=3
STATE_DIR="/var/run/watchdog"
mkdir -p "$STATE_DIR"
log() {
    logger -t watchdog "$1"
}
check_service() {
    local SVC="$1"
    systemctl is-active --quiet "$SVC"
}
for SVC in "${SERVICES[@]}"; do
    if check_service "$SVC"; then
        rm -f "$STATE_DIR/$SVC.restarts"
        continue
    fi
    COUNT_FILE="$STATE_DIR/$SVC.restarts"
    COUNT=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
    if [ "$COUNT" -ge $MAX_RESTARTS ]; then
        log "$SVC exceeded restart limit, giving up"
        continue
    fi
    log "$SVC down, restarting attempt $((COUNT + 1))"
    systemctl reset-failed "$SVC"
    systemctl start "$SVC"
    echo $((COUNT + 1)) > "$COUNT_FILE"
done
JOURNAL_TAIL=$(journalctl -p err -S "5 min ago" --no-pager | tail -n 20)
if [ -n "$JOURNAL_TAIL" ]; then
    echo "$JOURNAL_TAIL" > "$STATE_DIR/errors.log"
    grep -cE "(${SERVICES[*]})" "$STATE_DIR/errors.log" || true
fi
trap 'rm -f "$STATE_DIR"/*.restarts' EXIT
