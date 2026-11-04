#!/bin/bash
set -uo pipefail
QUEUE_DIR=${1:-/var/spool/postfix}
WARN=${2:-50}
CRIT=${3:-200}
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
if ! command -v postqueue >/dev/null 2>&1; then
    echo "postqueue not available" >&2
    exit 1
fi
postqueue -p > "$TMP"
if grep -q "Mail queue is empty" "$TMP"; then
    echo "queue empty"
    exit 0
fi
COUNT=$(awk '/^[A-F0-9]/ {n++} END {print n+0}' "$TMP")
HELD=$(awk '/^[A-F0-9]+!/ {n++} END {print n+0}' "$TMP")
declare -A REASONS=()
while IFS= read -r reason; do
    REASONS[$reason]=$(( ${REASONS[$reason]:-0} + 1 ))
done < <(awk '/^[A-F0-9]/ {getline; if ($0 ~ /\(/) {sub(/.*\(/, ""); sub(/\).*/, ""); print}}' "$TMP")
printf 'queue=%d held=%d\n' "$COUNT" "$HELD"
for reason in "${!REASONS[@]}"; do
    printf '%4d %s\n' "${REASONS[$reason]}" "$reason"
done | sort -rn | head -n 5
OLDEST_FILE=$(find "$QUEUE_DIR/deferred" "$QUEUE_DIR/active" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | head -n 1)
if [ -n "$OLDEST_FILE" ]; then
    AGE=$(( $(date +%s) - ${OLDEST_FILE%%.*} ))
    printf 'oldest message age: %ss\n' "$AGE"
fi
case "$COUNT" in
    0) LEVEL="ok" ;;
    *)
        if [ "$COUNT" -ge "$CRIT" ]; then
            LEVEL="critical"
        elif [ "$COUNT" -ge "$WARN" ]; then
            LEVEL="warning"
        else
            LEVEL="ok"
        fi
        ;;
esac
if [ "$LEVEL" != "ok" ]; then
    printf 'mail queue level=%s warn=%s crit=%s\n' "$LEVEL" "$WARN" "$CRIT" >&2
    du -sh "$QUEUE_DIR" 2>/dev/null
    exit 2
fi
printf 'mail queue level=ok\n'
exit 0
