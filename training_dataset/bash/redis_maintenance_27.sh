#!/bin/bash
REDIS_HOST="127.0.0.1"
REDIS_PORT="6379"
MAX_MEMORY_MB=2048
FRAG_LIMIT=1.5
INFO=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" info memory)
USED=$(echo "$INFO" | awk -F: "/used_memory:/ {gsub(/\r/, \"\"); print \$2}")
PEAK=$(echo "$INFO" | awk -F: "/used_memory_peak:/ {gsub(/\r/, \"\"); print \$2}")
FRAG=$(echo "$INFO" | awk -F: "/mem_fragmentation_ratio:/ {gsub(/\r/, \"\"); print \$2}")
USED_MB=$((USED / 1048576))
PEAK_MB=$((PEAK / 1048576))
echo "used=${USED_MB}MB peak=${PEAK_MB}MB frag=$FRAG"
if awk -v f="$FRAG" -v limit="$FRAG_LIMIT" "BEGIN {exit !(f > limit)}"; then
    logger -t redis_maint "fragmentation $FRAG exceeds $FRAG_LIMIT"
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" memory purge
fi
if [ "$USED_MB" -gt $MAX_MEMORY_MB ]; then
    echo "memory over policy limit" >&2
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config set maxmemory-policy allkeys-lru
fi
KEYS=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" dbsize)
STATS_INFO=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" info stats)
HITS=$(echo "$STATS_INFO" | awk -F: "/keyspace_hits:/ {gsub(/\r/, \"\"); print \$2}")
MISSES=$(echo "$STATS_INFO" | awk -F: "/keyspace_misses:/ {gsub(/\r/, \"\"); print \$2}")
if [ $((HITS + MISSES)) -gt 0 ]; then
    HIT_RATE=$((100 * HITS / (HITS + MISSES)))
    echo "keys=$KEYS hit_rate=${HIT_RATE}%"
fi
redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" bgsave
redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" lastsave
