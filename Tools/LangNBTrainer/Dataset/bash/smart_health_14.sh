#!/bin/bash
DISKS=$(lsblk -d -n -o NAME,TYPE | awk '$2 == "disk" {print "/dev/" $1}')
WARN_TEMP=55
ALERTS=0
for DISK in $DISKS; do
    if ! smartctl -H "$DISK" > /tmp/smart_out.txt 2>&1; then
        echo "$DISK smart unavailable" >&2
        continue
    fi
    HEALTH=$(awk -F": *" "/overall-health/ {print \$2}" /tmp/smart_out.txt)
    TEMP=$(smartctl -A "$DISK" | awk "/Temperature_Celsius/ {print \$10}")
    POWER_HOURS=$(smartctl -A "$DISK" | awk "/Power_On_Hours/ {print \$10}")
    REALLOC=$(smartctl -A "$DISK" | awk "/Reallocated_Sector_Ct/ {print \$10}")
    PENDING=$(smartctl -A "$DISK" | awk "/Current_Pending_Sector/ {print \$10}")
    echo "$DISK health=$HEALTH temp=${TEMP}C hours=$POWER_HOURS realloc=$REALLOC pending=$PENDING"
    case "$HEALTH" in
        PASSED)
            ;;
        *)
            echo "$DISK health: $HEALTH" >&2
            ALERTS=$((ALERTS + 1))
            ;;
    esac
    if [ -n "$TEMP" ] && [ "$TEMP" -ge $WARN_TEMP ]; then
        logger -t smart_watch "$DISK temperature $TEMP"
        ALERTS=$((ALERTS + 1))
    fi
    if [ "${REALLOC:-0}" -gt 0 ] || [ "${PENDING:-0}" -gt 0 ]; then
        echo "$DISK reallocated or pending sectors detected" >&2
        ALERTS=$((ALERTS + 1))
    fi
done
echo "alert count: $ALERTS"
test $ALERTS -gt 0 && exit 1
exit 0
