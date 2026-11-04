#!/bin/bash
set -uo pipefail
CACHE_ROOT=${1:-/var/cache/gitlab-runner}
MAX_SIZE_MB=${2:-4096}
MAX_AGE_DAYS=${3:-14}
DRY_RUN=${DRY_RUN:-0}
[ -d "$CACHE_ROOT" ] || { echo "cache root missing" >&2; exit 1; }
REMOVED=0
FREED=0
report() {
    printf 'removed=%s freed=%sMB dry_run=%s\n' "$REMOVED" "$FREED" "$DRY_RUN"
}
remove_path() {
    local path=$1
    local size
    size=$(du -sm "$path" | cut -f1)
    if [ "$DRY_RUN" = "1" ]; then
        printf 'would remove %s (%sMB)\n' "$path" "$size"
    else
        rm -rf "$path"
        printf 'removed %s (%sMB)\n' "$path" "$size"
    fi
    FREED=$((FREED + size))
    REMOVED=$((REMOVED + 1))
}
trap 'report; echo "interrupted" >&2' INT TERM
while IFS= read -r old; do
    remove_path "$old"
done < <(find "$CACHE_ROOT" -mindepth 2 -maxdepth 2 -type d -mtime +"$MAX_AGE_DAYS")
CURRENT=$(du -sm "$CACHE_ROOT" | cut -f1)
if [ "$CURRENT" -gt "$MAX_SIZE_MB" ]; then
    while IFS= read -r item; do
        [ "$CURRENT" -le "$MAX_SIZE_MB" ] && break
        remove_path "$item"
        CURRENT=$(du -sm "$CACHE_ROOT" | cut -f1)
    done < <(find "$CACHE_ROOT" -mindepth 2 -maxdepth 2 -type d -printf '%T@ %p\n' | sort -n | cut -d' ' -f2-)
fi
report
exit 0
