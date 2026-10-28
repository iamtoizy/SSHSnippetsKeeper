#!/bin/bash
API_URL="https://api.example.com/v2/incidents"
TOKEN_FILE="/etc/monitoring/token"
STATE_FILE="/var/cache/incidents.state"
TOKEN=$(cat "$TOKEN_FILE")
RESPONSE=$(curl -sS -H "Authorization: Bearer $TOKEN" "$API_URL") || {
    echo "api request failed" >&2
    exit 3
}
echo "$RESPONSE" | jq -r '.incidents[] | [.id, .severity, .status] | @tsv' |
while IFS=$'\t' read -r ID SEVERITY STATUS; do
    if grep -qx "$ID" "$STATE_FILE" 2>/dev/null; then
        continue
    fi
    echo "$ID" >> "$STATE_FILE"
    case "$SEVERITY" in
        critical)
            echo "CRITICAL incident $ID status=$STATUS"
            systemctl start notify-critical
            ;;
        warning)
            echo "WARNING incident $ID status=$STATUS"
            ;;
    esac
done
TOTAL=$(echo "$RESPONSE" | jq '.total')
OPEN=$(echo "$RESPONSE" | jq '[.incidents[] | select(.status == "open")] | length')
ASSIGNED=$(echo "$RESPONSE" | jq '[.incidents[] | select(.assignee != null)] | length')
echo "total=$TOTAL open=$OPEN assigned=$ASSIGNED"
test "$OPEN" -gt 0 && logger -t incidents "open incidents: $OPEN"
touch "$STATE_FILE"
