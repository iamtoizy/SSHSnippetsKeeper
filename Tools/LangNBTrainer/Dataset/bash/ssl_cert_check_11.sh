#!/bin/bash
HOSTS="example.com:443 api.example.com:8443 mail.example.com:993"
WARN_DAYS=21
REPORT="/var/run/cert_report.txt"
: > "$REPORT"
for ENDPOINT in $HOSTS; do
    HOST="${ENDPOINT%%:*}"
    PORT="${ENDPOINT##*:}"
    EXPIRY=$(echo | openssl s_client -servername "$HOST" -connect "$ENDPOINT" 2>/dev/null |
        openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
    if [ -z "$EXPIRY" ]; then
        echo "$HOST:$PORT no certificate" >&2
        continue
    fi
    EXPIRE_EPOCH=$(date -d "$EXPIRY" +%s)
    NOW_EPOCH=$(date +%s)
    DAYS_LEFT=$(( (EXPIRE_EPOCH - NOW_EPOCH) / 86400 ))
    ISSUER=$(echo | openssl s_client -servername "$HOST" -connect "$ENDPOINT" 2>/dev/null |
        openssl x509 -noout -issuer | sed 's/.*CN *= *//')
    printf "%-24s %3d days issuer=%s\n" "$HOST:$PORT" "$DAYS_LEFT" "$ISSUER" >> "$REPORT"
    if [ "$DAYS_LEFT" -lt $WARN_DAYS ]; then
        logger -t cert_watch "$HOST certificate expires in $DAYS_LEFT days"
    fi
done
if [ -s "$REPORT" ]; then
    mail -s "ssl certificate status" admin@example.com < "$REPORT"
    cat "$REPORT"
fi
EXPIRING=$(awk '$2 < 21 {count++} END {print count+0}' "$REPORT")
test "$EXPIRING" -gt 0 && exit 1
exit 0
