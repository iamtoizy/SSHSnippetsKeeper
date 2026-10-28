#!/bin/bash
LOG="/var/log/patching.log"
REBOOT_REQUIRED_FILE="/var/run/reboot-required"
echo "$(date +%F) patching started" >> "$LOG"
FAILED_TIMERS=$(systemctl list-timers --all --no-legend | awk "\$NF ~ /failed/ {print \$1}")
if [ -n "$FAILED_TIMERS" ]; then
    echo "failed timers detected" >&2
    for T in $FAILED_TIMERS; do
        systemctl restart "$T"
    done
fi
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
SECURITY=$(apt-get -s upgrade 2>/dev/null | grep -ci security)
echo "security upgrades available: $SECURITY" | tee -a "$LOG"
if [ "$SECURITY" -gt 0 ]; then
    apt-get -y -q upgrade 2>>"$LOG"
    if [ $? -ne 0 ]; then
        echo "upgrade failed" >&2
        exit 3
    fi
fi
NEEDS_RESTART=$(checkrestart 2>/dev/null | grep -c "restart")
if [ -f "$REBOOT_REQUIRED_FILE" ]; then
    echo "reboot required" | tee -a "$LOG"
    wall "reboot scheduled for tonight" 2>/dev/null
fi
AUTOREMOVE=$(apt-get -s autoremove | grep -c "^Remv")
apt-get -y -q autoremove > /dev/null
apt-get clean > /dev/null
echo "services needing restart: $NEEDS_RESTART autoremove pkgs: $AUTOREMOVE" | tee -a "$LOG"
systemd-analyze | head -n 1
journalctl --since today --no-pager | grep -i apt | tail -n 5
