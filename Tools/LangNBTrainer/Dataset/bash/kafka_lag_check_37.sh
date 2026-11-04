#!/bin/bash
set -uo pipefail
BROKER=${1:-localhost:9092}
GROUP=${2:-analytics-consumer}
THRESHOLD=${3:-5000}
OUTPUT=$(kafka-consumer-groups.sh --bootstrap-server "$BROKER" --group "$GROUP" --describe 2>/dev/null)
if [ -z "$OUTPUT" ]; then
    echo "cannot describe group $GROUP" >&2
    exit 1
fi
declare -A TOPIC_LAG=()
HOT=0
while read -r topic partition current end lag ; do
    case "$topic" in
        ""|TOPIC) continue ;;
    esac
    [ -z "$lag" ] && continue
    TOPIC_LAG[$topic]=$(( ${TOPIC_LAG[$topic]:-0} + lag ))
    if [ "$lag" -gt "$THRESHOLD" ]; then
        printf 'hot partition %s/%s lag=%s\n' "$topic" "$partition" "$lag" >&2
        HOT=$((HOT + 1))
    fi
done < <(printf '%s\n' "$OUTPUT" | awk 'NR>1 {print $2, $3, $4, $5, $6}')
TOTAL=0
for topic in "${!TOPIC_LAG[@]}"; do
    TOTAL=$((TOTAL + TOPIC_LAG[$topic]))
done
printf 'group=%s topics=%d total_lag=%d hot_partitions=%d\n' \
    "$GROUP" "${#TOPIC_LAG[@]}" "$TOTAL" "$HOT"
for topic in "${!TOPIC_LAG[@]}"; do
    printf '%s %s\n' "${TOPIC_LAG[$topic]}" "$topic"
done | sort -rn | head -n 5 | awk '{printf "top %-30s %s\n", $2, $1}'
if [ "$TOTAL" -gt $((THRESHOLD * 2)) ]; then
    printf 'consumer group is falling behind\n' >&2
    exit 3
fi
exit 0
