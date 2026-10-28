#!/bin/bash
ACTION="${1:-list}"
SET_NAME="banned"
TABLE="inet filter"
list_set() {
    nft list set "$TABLE" "$SET_NAME" 2>/dev/null | grep -E "^\s*[0-9]+\." | tr -d " \t"
}
case "$ACTION" in
    list)
        nft list ruleset | head -n 60
        echo "banned addresses:"
        list_set
        ;;
    ban)
        IP="${2:?ip required}"
        nft add element "$TABLE" "$SET_NAME" "{ $IP }"
        logger -t firewall "banned $IP"
        echo "banned $IP"
        ;;
    unban)
        IP="${2:?ip required}"
        nft delete element "$TABLE" "$SET_NAME" "{ $IP }" 2>/dev/null
        logger -t firewall "unbanned $IP"
        echo "unbanned $IP"
        ;;
    flush)
        nft flush set "$TABLE" "$SET_NAME"
        echo "set $SET_NAME flushed"
        ;;
    *)
        echo "usage: $0 {list|ban|unban|flush} [ip]" >&2
        exit 64
        ;;
esac
COUNT=$(list_set | wc -l)
echo "entries in $SET_NAME: $COUNT"
POLICY=$(nft list chain "$TABLE" input 2>/dev/null | grep -oP "policy \w+")
echo "input chain $POLICY"
iptables -S 2>/dev/null | wc -l
