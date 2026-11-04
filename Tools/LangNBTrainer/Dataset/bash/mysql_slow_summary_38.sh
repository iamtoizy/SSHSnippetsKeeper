#!/bin/bash
set -uo pipefail
SLOW_LOG=${1:-/var/log/mysql/mysql-slow.log}
TOP=${2:-5}
LONG_MS=${3:-2000}
[ -r "$SLOW_LOG" ] || { printf 'unreadable: %s\n' "$SLOW_LOG" >&2; exit 1; }
WORK=$(mktemp)
trap 'rm -f "$WORK"' EXIT
awk -v limit="$LONG_MS" '
    /^# Query_time:/ {
        t = $3 + 0
        if (t * 1000 >= limit) {
            count++
            sum += t
            if (t > worst) worst = t
        }
    }
    END {printf "%d %.3f %.3f\n", count, sum, worst}
' "$SLOW_LOG" > "$WORK"
read -r COUNT SUM WORST < "$WORK"
printf 'slow queries over %sms: %d\n' "$LONG_MS" "$COUNT"
if [ "$COUNT" -eq 0 ]; then
    printf 'no slow queries found\n'
    exit 0
fi
awk -v s="$SUM" -v c="$COUNT" 'BEGIN {printf "average: %.3fs\n", s / c}'
printf 'worst: %ss\n' "$WORST"
awk -v limit="$LONG_MS" '
    /^# User@Host: / {user = $3}
    /^# Query_time:/ {
        if (($3 + 0) * 1000 >= limit && user != "") {
            print user
            user = ""
        }
    }
' "$SLOW_LOG" | sed 's/\[.*//' \
    | sort | uniq -c | sort -rn | head -n "$TOP" \
    | awk '{printf "user %-16s %s queries\n", $2, $1}'
if [ "$COUNT" -gt 50 ]; then
    printf 'threshold breach: review slow log configuration\n' >&2
    exit 3
fi
exit 0
