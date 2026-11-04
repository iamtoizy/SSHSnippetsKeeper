#!/bin/bash
THRESHOLD=85
EXCLUDE="/dev/loop|tmpfs|squashfs"
HOSTNAME=$(hostname -s)
REPORT="/tmp/disk_report.$$"
awk -v thresh="$THRESHOLD" -v exclude="$EXCLUDE" '
    NR == 1 {next}
    $1 ~ exclude {next}
    {
        gsub(/%/, "", $5)
        if ($5 + 0 >= thresh) {
            printf "%s %s %s\n", $1, $6, $5
        }
    }
' <(df -hP) > "$REPORT"
if [ ! -s "$REPORT" ]; then
    rm -f "$REPORT"
    exit 0
fi
INODE_ALERT=$(df -iP | awk -v t=90 'NR>1 {gsub(/%/,"",$5); if ($5+0 >= t) print $6}')
while read -r DEV MOUNT PCT; do
    logger -t disk_alert "$MOUNT at $PCT on $DEV"
    case "$PCT" in
        9[5-9]|100)
            systemctl start cleanup-heavy
            ;;
        *)
            echo "watch $MOUNT ($PCT)"
            ;;
    esac
done < "$REPORT"
if [ -n "$INODE_ALERT" ]; then
    echo "inode pressure: $INODE_ALERT" >&2
fi
BIGGEST=$(du -xh / 2>/dev/null | sort -rh | head -n 5)
echo "$BIGGEST"
mail -s "[$HOSTNAME] disk alert" ops@example.com < "$REPORT"
rm -f "$REPORT"
