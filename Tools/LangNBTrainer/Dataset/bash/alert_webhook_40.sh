#!/bin/bash
set -uo pipefail
ENDPOINT=${WEBHOOK_URL:?webhook url required}
CHANNEL=${CHANNEL:-alerts}
MAX_RETRY=3
send_payload() {
    local message=$1
    local attempt=1
    local code
    local body
    body=$(printf '{"channel":"%s","text":"%s"}' "$CHANNEL" "$(printf '%s' "$message" | sed 's/"/\\"/g')")
    while [ "$attempt" -le "$MAX_RETRY" ]; do
        code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
            -H 'Content-Type: application/json' --data "$body" "$ENDPOINT")
        case "$code" in
            2*) echo "delivered on attempt $attempt"; return 0 ;;
            429|5*) echo "retryable status $code (attempt $attempt)" >&2 ;;
            *) echo "permanent failure $code" >&2; return 1 ;;
        esac
        attempt=$((attempt + 1))
        sleep $((attempt * 2))
    done
    return 1
}
trap 'echo "aborted by signal" >&2; exit 130' INT TERM
MESSAGE=${1:-"deploy finished at $(date -Is)"}
if send_payload "$MESSAGE"; then
    exit 0
fi
printf 'webhook failed for %s\n' "$ENDPOINT" >&2
exit 4
