#!/bin/bash
VG="vg0"
LV="data"
SNAP_NAME="data_backup"
SNAP_SIZE="5G"
free_extents() {
    vgs --noheadings -o vg_free_count "$VG" | tr -d " "
}
if [ "$(free_extents)" -eq 0 ]; then
    echo "volume group $VG is full" >&2
    exit 2
fi
EXISTING=$(lvs --noheadings -o lv_name "$VG" | grep -c "$SNAP_NAME")
if [ "$EXISTING" -gt 0 ]; then
    echo "removing stale snapshot"
    lvremove -f "$VG/$SNAP_NAME"
fi
lvcreate -s -L "$SNAP_SIZE" -n "$SNAP_NAME" "$VG/$LV"
if [ $? -ne 0 ]; then
    echo "snapshot creation failed" >&2
    exit 3
fi
MOUNT="/mnt/snapshot"
mkdir -p "$MOUNT"
mount -o ro "/dev/$VG/$SNAP_NAME" "$MOUNT"
tar -czf "/var/backups/${LV}-$(date +%F).tar.gz" -C "$MOUNT" .
SNAP_USAGE=$(lvs --noheadings -o data_percent "$VG/$SNAP_NAME" | tr -d " ")
umount "$MOUNT"
lvremove -f "$VG/$SNAP_NAME"
echo "snapshot usage was: ${SNAP_USAGE:-0}%"
ARCHIVE="/var/backups/${LV}-$(date +%F).tar.gz"
sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"
find /var/backups -name "${LV}-*.tar.gz" -mtime +14 -delete
FREE=$(free_extents)
echo "free extents after backup: $FREE"
df -h /var/backups | awk "NR==2 {print \"backup fs:\", \$5}"
logger -t lvm_snap "backup finished for $VG/$LV"
