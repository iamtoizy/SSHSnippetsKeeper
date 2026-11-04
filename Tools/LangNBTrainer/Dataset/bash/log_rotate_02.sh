#!/bin/bash
LOG_DIR="/var/log/app"
ARCHIVE_DIR="/var/log/app/archive"
DAYS_TO_KEEP=14
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p "$ARCHIVE_DIR"
FILES=$(find "$LOG_DIR" -maxdepth 1 -name "*.log" -size +10M)
for FILE in $FILES; do
    BASENAME=$(basename "$FILE")
    gzip -c "$FILE" > "$ARCHIVE_DIR/${BASENAME}.${TIMESTAMP}.gz"
    : > "$FILE"
    logger -t log_rotate "rotated $BASENAME"
done
find "$ARCHIVE_DIR" -name "*.gz" -mtime +$DAYS_TO_KEEP -delete
COUNT=$(find "$ARCHIVE_DIR" -name "*.gz" | wc -l)
case "$COUNT" in
    0)
        echo "no archives present" >&2
        exit 1
        ;;
    1|2|3)
        echo "low archive count: $COUNT"
        ;;
    *)
        echo "$COUNT archives stored in $ARCHIVE_DIR"
        ;;
esac
LARGEST=$(du -ah "$ARCHIVE_DIR" | sort -rh | head -n 1)
echo "largest archive: $LARGEST"
df -h "$LOG_DIR" | awk 'NR==2 {print "usage:", $5}'
OLDEST=$(find "$ARCHIVE_DIR" -name "*.gz" -printf "%T@ %p\n" | sort -n | head -1 | cut -d' ' -f2)
[ -n "$OLDEST" ] && echo "oldest: $OLDEST"
exit 0
