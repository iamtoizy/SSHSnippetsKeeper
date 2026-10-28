#!/bin/bash
HOSTS="8.8.8.8 1.1.1.1 gateway.local"
INTERVAL=5
FAIL_LIMIT=3
declare -A FAILCOUNT
while true; do
    for HOST in $HOSTS; do
        if ping -c 1 -W 2 "$HOST" > /dev/null 2>&1; then
            FAILCOUNT[$HOST]=0
            RTT=$(ping -c 1 -W 2 "$HOST" | awk -F'time=' '/time=/{print $2}' | cut -d' ' -f1)
            echo "$(date +%T) $HOST ok rtt=${RTT}ms"
        else
            FAILCOUNT[$HOST]=$(( ${FAILCOUNT[$HOST]:-0} + 1 ))
            echo "$(date +%T) $HOST fail ${FAILCOUNT[$HOST]}" >&2
            if [ ${FAILCOUNT[$HOST]} -ge $FAIL_LIMIT ]; then
                logger -t net_monitor "host $HOST unreachable"
                systemctl restart wpa_supplicant
                FAILCOUNT[$HOST]=0
            fi
        fi
    done
    RX=$(awk '/eth0/ {print $2}' /proc/net/dev)
    TX=$(awk '/eth0/ {print $10}' /proc/net/dev)
    echo "$(date +%T) eth0 rx=$RX tx=$TX"
    LOAD=$(awk '{print $1}' /proc/loadavg)
    CONNS=$(ss -tan state established | tail -n +2 | wc -l)
    if awk -v l="$LOAD" 'BEGIN {exit !(l > 4.0)}'; then
        logger -t net_monitor "load average critical: $LOAD"
    fi
    echo "$(date +%T) established=$CONNS load=$LOAD"
    sleep $INTERVAL
done
