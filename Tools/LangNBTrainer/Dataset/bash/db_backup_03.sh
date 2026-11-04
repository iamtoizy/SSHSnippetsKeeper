#!/bin/bash
BACKUP_ROOT="/var/backups/postgres"
DBS="appdb billingdb analytics"
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TARGET="$BACKUP_ROOT/$TIMESTAMP"
cleanup() {
    rm -f "$TARGET"/*.tmp
    logger -t db_backup "cleanup finished"
}
trap cleanup EXIT
mkdir -p "$TARGET"
chmod 700 "$TARGET"
for DB in $DBS; do
    pg_dump -Fc -f "$TARGET/$DB.dump" "$DB"
    if [ $? -ne 0 ]; then
        echo "backup failed for $DB" >&2
        exit 2
    fi
    SIZE=$(du -h "$TARGET/$DB.dump" | awk '{print $1}')
    echo "$DB dumped: $SIZE"
done
sha256sum "$TARGET"/*.dump > "$TARGET/SHA256SUMS"
find "$BACKUP_ROOT" -maxdepth 1 -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \;
aws s3 sync "$TARGET" "s3://corp-backups/postgres/$TIMESTAMP" --quiet
VERIFY=$(sha256sum -c "$TARGET/SHA256SUMS" | grep -c OK)
if [ "$VERIFY" -ne 3 ]; then
    echo "checksum verification failed" >&2
    exit 4
fi
psql -d appdb -c "select pg_backup_start(label => 'nightly')" > /dev/null
echo "backup complete: $TARGET"
du -sh "$BACKUP_ROOT" | awk '{print "total size:", $1}'
