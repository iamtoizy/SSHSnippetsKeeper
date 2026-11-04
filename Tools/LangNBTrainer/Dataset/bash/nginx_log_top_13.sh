#!/bin/bash
LOG="/var/log/nginx/access.log"
WINDOW_LINES=50000
REPORT="/tmp/nginx_top.txt"
tail -n $WINDOW_LINES "$LOG" > /tmp/nginx_window.log
echo "top clients:"
awk '{print $1}' /tmp/nginx_window.log | sort | uniq -c | sort -rn | head -n 10
echo "top urls:"
awk '{print $7}' /tmp/nginx_window.log | sort | uniq -c | sort -rn | head -n 10
echo "status codes:"
awk '{codes[$9]++} END {for (c in codes) print c, codes[c]}' /tmp/nginx_window.log | sort -n
awk '
    {
        total++
        if ($9 ~ /^4/) client_errors++
        if ($9 ~ /^5/) server_errors++
        bytes += $10
        minute = substr($4, 2, 17)
        per_minute[minute]++
    }
    END {
        printf "total=%d 4xx=%d 5xx=%d avg_bytes=%d\n", total, client_errors, server_errors, total ? bytes/total : 0
        peak = 0
        for (m in per_minute) {
            if (per_minute[m] > peak) {
                peak = per_minute[m]
                peak_minute = m
            }
        }
        printf "peak_minute=%s requests=%d\n", peak_minute, peak
    }
' /tmp/nginx_window.log > "$REPORT"
cat "$REPORT"
ERRORS=$(awk -F"[= ]" "/4xx=/{print \$4}" "$REPORT")
if [ "${ERRORS:-0}" -gt 1000 ]; then
    logger -t nginx_watch "elevated 4xx: $ERRORS"
    tail -n 100 "$LOG" | grep " 4[0-9][0-9] " | awk '{print $1}' | sort -u > /tmp/suspects.txt
    wc -l /tmp/suspects.txt
fi
sed -i "s/[0-9]\{1,3\}\.[0-9]\{1,3\}\./x.x./g" "$REPORT"
grep -c "x.x." "$REPORT"
rm -f /tmp/nginx_window.log
