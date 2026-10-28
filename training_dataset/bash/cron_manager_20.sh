#!/bin/bash
ACTION="${1:-list}"
CRON_BACKUP="/var/backups/crontab-$(date +%F).bak"
backup_crontab() {
    crontab -l > "$CRON_BACKUP" 2>/dev/null || touch "$CRON_BACKUP"
}
list_jobs() {
    crontab -l 2>/dev/null | grep -v "^$"
}
case "$ACTION" in
    list)
        list_jobs
        COUNT=$(list_jobs | wc -l)
        echo "total jobs: $COUNT"
        ;;
    backup)
        backup_crontab
        echo "saved to $CRON_BACKUP"
        sha256sum "$CRON_BACKUP"
        ;;
    dedupe)
        backup_crontab
        crontab -l | awk "!seen[\$0]++" | crontab -
        BEFORE=$(wc -l < "$CRON_BACKUP")
        AFTER=$(crontab -l | wc -l)
        echo "removed $((BEFORE - AFTER)) duplicates"
        ;;
    install)
        JOB_FILE="${2:?job file required}"
        backup_crontab
        while IFS= read -r LINE; do
            [ -z "$LINE" ] && continue
            if crontab -l | grep -qF "$LINE"; then
                echo "already present: $LINE"
            else
                (crontab -l; echo "$LINE") | crontab -
                echo "installed: $LINE"
            fi
        done < "$JOB_FILE"
        ;;
    *)
        echo "usage: $0 {list|backup|dedupe|install file}" >&2
        exit 64
        ;;
esac
VALID=$(crontab -l 2>/dev/null | grep -cE "^([0-9*,\/-]+ ){5}")
echo "valid cron lines: $VALID"
