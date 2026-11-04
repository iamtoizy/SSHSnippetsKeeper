#!/bin/bash
set -uo pipefail
IFACE=${1:-wg0}
MAX_AGE=${2:-180}
declare -a STALE=()
declare -a ACTIVE=()
if ! command -v wg >/dev/null 2>&1; then
    echo "wg not installed" >&2
    exit 1
fi
NOW=$(date +%s)
while IFS=$'\t' read -r pub preshared endpoint allowed latest rx tx keepalive; do
    [ -z "${pub:-}" ] && continue
    if [ "$latest" = "0" ]; then
        age=-1
    else
        age=$(( NOW - latest ))
    fi
    label=$(printf '%s' "$pub" | cut -c1-12)
    if [ "$age" -lt 0 ] || [ "$age" -gt "$MAX_AGE" ]; then
        STALE+=("$label age=${age}s")
    else
        ACTIVE+=("$label rx=$rx tx=$tx age=${age}s")
    fi
done < <(wg show "$IFACE" dump | tail -n +2)
printf 'active peers: %d\n' "${#ACTIVE[@]}"
printf 'stale peers: %d\n' "${#STALE[@]}"
for entry in "${STALE[@]:-}"; do
    [ -n "$entry" ] && printf 'stale %s\n' "$entry" >&2
done
if [ "${#STALE[@]}" -gt 0 ]; then
    printf '%s\n' "${STALE[@]}" | sed 's/^/alert: /'
    exit 3
fi
printf '%s\n' "${ACTIVE[@]}" | sort -t= -k3 -n | head -n 5
exit 0
