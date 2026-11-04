#!/bin/bash
set -uo pipefail
RESOLVER=${RESOLVER:-1.1.1.1}
declare -A EXPECTED=(
    [api.example.com]="203.0.113.10"
    [www.example.com]="203.0.113.10"
    [mail.example.com]="198.51.100.25"
    [vpn.example.com]="198.51.100.40"
)
DRIFT=0
probe() {
    local host=$1
    dig +short +time=2 +tries=2 "@$RESOLVER" "$host" A | head -n 1
}
for host in "${!EXPECTED[@]}"; do
    want=${EXPECTED[$host]}
    got=$(probe "$host")
    if [ -z "$got" ]; then
        printf 'NXDOMAIN or timeout for %s\n' "$host" >&2
        DRIFT=$((DRIFT + 1))
    elif [ "$got" = "$want" ]; then
        printf 'ok   %-20s %s\n' "$host" "$got"
    else
        printf 'drift %-19s expected=%s got=%s\n' "$host" "$want" "$got" >&2
        DRIFT=$((DRIFT + 1))
    fi
done
CHECKED=${#EXPECTED[@]}
printf 'checked: %s records via %s\n' "$CHECKED" "$RESOLVER"
if [ "$DRIFT" -gt 0 ]; then
    printf '%d record(s) out of sync\n' "$DRIFT"
    exit 2
fi
printf 'zone consistent\n'
