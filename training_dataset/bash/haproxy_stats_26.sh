#!/bin/bash
SOCKET="/run/haproxy/admin.sock"
CSV_FILE="/tmp/haproxy_stats.csv"
echo "show stat" | socat unix-connect:"$SOCKET" > "$CSV_FILE" 2>/dev/null
if [ ! -s "$CSV_FILE" ]; then
    echo "stats socket unavailable" >&2
    exit 2
fi
awk -F, "
    NR == 1 {next}
    \$2 ~ /FRONTEND/ {printf \"frontend %-20s rate=%s sess=%s\n\", \$1, \$41, \$8}
    \$2 ~ /BACKEND/ && \$18 > 0 {printf \"backend %-20s down_servers=%s\n\", \$1, \$18}
" "$CSV_FILE"
DOWN=$(awk -F, "NR>1 && \$2 !~ /FRONTEND|BACKEND/ && \$18 == 0 {print \$1\"/\"\$2}" "$CSV_FILE")
if [ -n "$DOWN" ]; then
    echo "servers down:" >&2
    echo "$DOWN" >&2
fi
QUEUE=$(awk -F, "NR>1 {q += \$3} END {print q+0}" "$CSV_FILE")
RESP_TIME=$(awk -F, "NR>1 && \$2 !~ /FRONTEND|BACKEND/ {t += \$16; n++} END {print int(t/n)}" "$CSV_FILE")
echo "queued=$QUEUE avg_response=${RESP_TIME}ms"
MAX_SESS=$(awk -F, "NR>1 && \$2 ~ /FRONTEND/ {if (\$8+0 > m) {m = \$8; f = \$1}} END {print f, m}" "$CSV_FILE")
echo "busiest frontend: $MAX_SESS"
grep -c "UP" "$CSV_FILE" > /dev/null && echo "health checks present"
