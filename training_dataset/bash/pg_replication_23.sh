#!/bin/bash
REPL_USER="replicator"
SLAVES="pg2.internal pg3.internal"
MAX_LAG_MB=32
LAG_QUERY="select coalesce(round(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) / 1048576), 0) from pg_stat_replication"
for SLAVE in $SLAVES; do
    LAG=$(psql -h "$SLAVE" -U "$REPL_USER" -d postgres -tAc "$LAG_QUERY" 2>/dev/null)
    if [ -z "$LAG" ]; then
        echo "$SLAVE unreachable" >&2
        continue
    fi
    if [ "$LAG" -gt $MAX_LAG_MB ]; then
        logger -t pg_repl "$SLAVE lag $LAG MB exceeds limit"
        echo "$SLAVE lag: $LAG MB" >&2
    else
        echo "$SLAVE lag ok: $LAG MB"
    fi
done
psql -h localhost -U postgres -d postgres <<'SQL'
select application_name, state, sync_state
from pg_stat_replication;
SQL
SLOTS=$(psql -U postgres -d postgres -tAc "select count(*) from pg_replication_slots where active = false")
if [ "${SLOTS:-0}" -gt 0 ]; then
    echo "inactive replication slots: $SLOTS" >&2
    psql -U postgres -d postgres -c "select slot_name, active from pg_replication_slots where active = false"
fi
WAL_SIZE=$(du -sm /var/lib/postgresql/main/pg_wal 2>/dev/null | awk "{print \$1}")
echo "wal directory size: ${WAL_SIZE:-unknown} MB"
CHECKPOINT=$(psql -U postgres -d postgres -tAc "select checkpoints_timed from pg_bgwriter" 2>/dev/null)
echo "checkpoints timed: ${CHECKPOINT:-n/a}"
