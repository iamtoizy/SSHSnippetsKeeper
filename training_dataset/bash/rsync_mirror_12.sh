#!/bin/bash
SRC="/srv/www/"
DST="/mnt/backup/www/"
EXCLUDES="*.log cache/ tmp/"
LOCK_FILE="/var/run/mirror.lock"
DRY_RUN="${1:-no}"
acquire_lock() {
    exec 200>"$LOCK_FILE"
    flock -n 200 || {
        echo "another mirror is running" >&2
        exit 75
    }
}
build_args() {
    ARGS=(-az --delete --stats --numeric-ids)
    for PATTERN in $EXCLUDES; do
        ARGS+=(--exclude="$PATTERN")
    done
    if [ "$DRY_RUN" = "dry" ]; then
        ARGS+=(--dry-run)
    fi
}
acquire_lock
build_args
rsync "${ARGS[@]}" "$SRC" "$DST" > /tmp/rsync_stats.txt 2>&1
RC=$?
if [ $RC -ne 0 ]; then
    echo "rsync exited with $RC" >&2
    tail -n 5 /tmp/rsync_stats.txt >&2
    exit $RC
fi
grep -E "files transferred|total size" /tmp/rsync_stats.txt
DELETED=$(grep -oP "(?<=deleted: )\d+" /tmp/rsync_stats.txt || echo 0)
CHANGED=$(grep -oP "(?<=files transferred: )\d+" /tmp/rsync_stats.txt || echo 0)
logger -t mirror "changed=$CHANGED deleted=$DELETED mode=$DRY_RUN"
if [ "$CHANGED" -gt 5000 ]; then
    echo "unusual change volume: $CHANGED" >&2
fi
ssh backup@nas.example.com "df -h /mnt/backup" | awk 'NR==2 {print "remote usage:", $5}'
rm -f /tmp/rsync_stats.txt
