#!/bin/bash
VHOST="prod"
WARN_DEPTH=10000
CRIT_DEPTH=50000
DEPTH_LINE=$(rabbitmqctl -p "$VHOST" list_queues name messages_ready messages_unacknowledged 2>/dev/null)
if [ -z "$DEPTH_LINE" ]; then
    echo "rabbitmqctl failed" >&2
    exit 2
fi
echo "$DEPTH_LINE" | tail -n +2 | while read -r QUEUE READY UNACKED; do
    [ -z "$QUEUE" ] && continue
    TOTAL=$((READY + UNACKED))
    STATE=ok
    if [ "$TOTAL" -ge $CRIT_DEPTH ]; then
        STATE=critical
    elif [ "$TOTAL" -ge $WARN_DEPTH ]; then
        STATE=warning
    fi
    printf "%-30s ready=%-8d unacked=%-8d state=%s\n" "$QUEUE" "$READY" "$UNACKED" "$STATE"
    case "$STATE" in
        critical)
            logger -t rmq_watch "queue $QUEUE critical depth $TOTAL"
            rabbitmqctl -p "$VHOST" purge_queue "$QUEUE" > /dev/null
            ;;
        warning)
            logger -t rmq_watch "queue $QUEUE warning depth $TOTAL"
            ;;
    esac
done
CONSUMERS=$(rabbitmqctl -p "$VHOST" list_queues name consumers 2>/dev/null | awk "NR>1 && \$2 == 0 {print \$1}")
if [ -n "$CONSUMERS" ]; then
    echo "queues without consumers:" >&2
    echo "$CONSUMERS" >&2
fi
NODES=$(rabbitmqctl cluster_status 2>/dev/null | grep -c "running_nodes")
UPTIME=$(rabbitmqctl status 2>/dev/null | awk -F", " "/Uptime/ {print \$1}")
echo "clusters: $NODES uptime: $UPTIME"
