#!/bin/bash
SWAP_THRESHOLD=25
TOP_CONSUMERS=8
MEM_TOTAL=$(awk "/MemTotal/ {print int(\$2/1024)}" /proc/meminfo)
MEM_AVAIL=$(awk "/MemAvailable/ {print int(\$2/1024)}" /proc/meminfo)
SWAP_TOTAL=$(awk "/SwapTotal/ {print int(\$2/1024)}" /proc/meminfo)
SWAP_FREE=$(awk "/SwapFree/ {print int(\$2/1024)}" /proc/meminfo)
MEM_USED_PCT=$(( 100 * (MEM_TOTAL - MEM_AVAIL) / MEM_TOTAL ))
if [ "$SWAP_TOTAL" -gt 0 ]; then
    SWAP_USED_PCT=$(( 100 * (SWAP_TOTAL - SWAP_FREE) / SWAP_TOTAL ))
else
    SWAP_USED_PCT=0
fi
echo "ram used: ${MEM_USED_PCT}% (${MEM_AVAIL}MB free of ${MEM_TOTAL}MB)"
echo "swap used: ${SWAP_USED_PCT}%"
if [ "$SWAP_USED_PCT" -ge $SWAP_THRESHOLD ]; then
    logger -t mem_watch "swap pressure ${SWAP_USED_PCT}%"
    CURRENT=$(sysctl -n vm.swappiness)
    if [ "$CURRENT" -gt 10 ]; then
        sysctl -w vm.swappiness=10 > /dev/null
        echo "swappiness lowered: $CURRENT -> 10"
    fi
    systemctl restart earlyoom 2>/dev/null || true
fi
ps aux --sort=-%mem | head -n $((TOP_CONSUMERS + 1)) | awk "NR>1 {printf \"%-10s %5s%% %s\n\", \$1, \$4, \$11}"
HUGEPAGES=$(sysctl -n vm.nr_hugepages)
echo "hugepages: $HUGEPAGES"
CACHED=$(awk "/^Cached/ {print int(\$2/1024)}" /proc/meminfo)
echo "page cache: ${CACHED}MB"
sync
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || echo "drop_caches skipped" >&2
