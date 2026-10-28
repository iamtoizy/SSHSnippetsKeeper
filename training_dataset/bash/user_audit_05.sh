#!/bin/bash
MIN_UID=1000
AUDIT_LOG="/var/log/user_audit.log"
check_user() {
    local USERNAME="$1"
    local USER_SHELL="$3"
    local LAST_LOGIN
    LAST_LOGIN=$(lastlog -u "$USERNAME" | awk 'NR==2 {print $4, $5, $8}')
    if [ "$USER_SHELL" = "/sbin/nologin" ]; then
        return 0
    fi
    if [ -z "$LAST_LOGIN" ] || [ "$LAST_LOGIN" = "Never log" ]; then
        echo "$USERNAME never logged in" >&2
        echo "$(date +%F) stale $USERNAME" >> "$AUDIT_LOG"
    else
        echo "$(date +%F) active $USERNAME last=$LAST_LOGIN" >> "$AUDIT_LOG"
    fi
}
awk -F: -v min="$MIN_UID" '$3 >= min {print $1, $3, $7}' /etc/passwd |
while read -r USERNAME UID_NUM USER_SHELL; do
    check_user "$USERNAME" "$UID_NUM" "$USER_SHELL"
done
EXPIRED=$(chage -l root | grep -c "never")
SUDOERS=$(awk -F: '$1 ~ /sudo|wheel/ {print}' /etc/group | wc -l)
LOCKED=$(passwd -S root | awk '{print $2}')
echo "expired checks: $EXPIRED"
echo "admin groups: $SUDOERS"
echo "root status: $LOCKED"
sort -u "$AUDIT_LOG" -o "$AUDIT_LOG"
wc -l "$AUDIT_LOG"
