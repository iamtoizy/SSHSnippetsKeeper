#!/bin/bash
set -uo pipefail
AUTH_LOG=${1:-/var/log/auth.log}
REPORT=${2:-/var/report/failed_logins.txt}
THRESHOLD=${3:-10}
if [ ! -r "$AUTH_LOG" ]; then
    echo "cannot read $AUTH_LOG" >&2
    exit 1
fi
mkdir -p "$(dirname "$REPORT")"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
awk '/Failed password/ {for (i=1;i<=NF;i++) if ($i=="from") print $(i+1)}' "$AUTH_LOG" \
    | sort | uniq -c | sort -rn > "$TMP"
TOTAL=$(awk '{sum += $1} END {print sum+0}' "$TMP")
UNIQUE=$(wc -l < "$TMP")
echo "failed attempts: $TOTAL from $UNIQUE addresses"
while read -r count ip; do
    if [ "$count" -ge "$THRESHOLD" ]; then
        printf '%s %s above threshold\n' "$ip" "$count"
        echo "$ip" >> "$REPORT"
    fi
done < "$TMP"
if command -v nft >/dev/null 2>&1 && [ -s "$REPORT" ]; then
    sort -u "$REPORT" -o "$REPORT"
    echo "blocklist entries: $(wc -l < "$REPORT")"
fi
awk -v t="$TOTAL" 'BEGIN {printf "severity: %s\n", (t > 100 ? "high" : (t > 20 ? "medium" : "low"))}'
exit 0
