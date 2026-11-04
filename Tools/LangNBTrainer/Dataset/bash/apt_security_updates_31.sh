#!/bin/bash
set -uo pipefail
REBOOT_FLAG="/var/run/reboot-required"
MIN_CRITICAL=${1:-0}
declare -a PENDING=()
mapfile -t PENDING < <(apt-get -s dist-upgrade 2>/dev/null | awk '/^Inst/ && /security/ {print $2}')
TOTAL=${#PENDING[@]}
echo "security updates pending: $TOTAL"
if [ "$TOTAL" -gt 0 ]; then
    printf '%s\n' "${PENDING[@]}" | sed 's/^/  - /'
    printf '%s\n' "${PENDING[@]}" > /var/tmp/security-updates.list
fi
case "$TOTAL" in
    0) STATUS="clean" ;;
    1|2|3) STATUS="low" ;;
    *)
        if [ "$TOTAL" -gt 20 ]; then
            STATUS="critical"
        else
            STATUS="elevated"
        fi
        ;;
esac
if [ -f "$REBOOT_FLAG" ]; then
    echo "reboot required" >&2
fi
echo "status=$STATUS count=$TOTAL"
awk -v c="$TOTAL" -v m="$MIN_CRITICAL" 'BEGIN {exit !(c >= m)}'
exit $?
