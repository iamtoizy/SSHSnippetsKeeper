#!/bin/bash
JAILS=$(fail2ban-client status 2>/dev/null | grep "Jail list" | sed "s/.*://; s/,/ /g")
if [ -z "$JAILS" ]; then
    echo "fail2ban is not responding" >&2
    exit 2
fi
TOTAL=0
for JAIL in $JAILS; do
    INFO=$(fail2ban-client status "$JAIL")
    BANNED=$(echo "$INFO" | grep "Currently banned" | awk "{print \$NF}")
    EVER=$(echo "$INFO" | grep "Total banned" | awk "{print \$NF}")
    TOTAL=$((TOTAL + BANNED))
    if [ "$BANNED" -gt 0 ]; then
        echo "jail=$JAIL banned=$BANNED total=$EVER"
        IP_LIST=$(echo "$INFO" | grep "Banned IP list" | sed "s/.*://")
        for IP in $IP_LIST; do
            RESOLVED=$(getent hosts "$IP" | awk "{print \$2}" | head -1)
            printf "  %-16s %s\n" "$IP" "${RESOLVED:-unknown}"
        done
    fi
done
echo "currently banned across jails: $TOTAL"
case "${1:-report}" in
    report)
        fail2ban-client banned | head -c 400
        echo
        ;;
    flush)
        if [ "$TOTAL" -gt 0 ]; then
            for JAIL in $JAILS; do
                fail2ban-client set "$JAIL" unbanip --all
            done
            echo "all jails unbanned"
        fi
        ;;
    *)
        echo "usage: $0 {report|flush}" >&2
        exit 64
        ;;
esac
grep -h "Ban " /var/log/fail2ban.log 2>/dev/null | awk "{print \$NF}" | sort | uniq -c | sort -rn | head -n 5
