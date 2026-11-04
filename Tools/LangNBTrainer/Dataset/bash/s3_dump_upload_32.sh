#!/bin/bash
set -euo pipefail
SOURCE_DIR=${1:-/var/lib/postgresql/dumps}
BUCKET=${2:-s3://company-backups/postgres}
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
WORK_DIR=$(mktemp -d)
ARCHIVE="$WORK_DIR/dump-$STAMP.tar.gz"
cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM
upload() {
    local file=$1
    local target=$2
    local bucket
    local key
    bucket=$(printf '%s' "$target" | cut -d/ -f3)
    key=$(printf '%s' "$target" | cut -d/ -f4-)
    aws s3 cp "$file" "$target" --only-show-errors
    aws s3api head-object --bucket "$bucket" --key "$key" >/dev/null
}
tar -czf "$ARCHIVE" -C "$SOURCE_DIR" .
SIZE=$(stat -c %s "$ARCHIVE")
if [ "$SIZE" -lt 1024 ]; then
    echo "archive too small: $SIZE bytes" >&2
    exit 2
fi
upload "$ARCHIVE" "$BUCKET/dump-$STAMP.tar.gz"
OLD=$(aws s3 ls "$BUCKET/" | awk '{print $4}' | sort | head -n -7)
for KEY in $OLD; do
    aws s3 rm "$BUCKET/$KEY" --only-show-errors
    echo "pruned $KEY"
done
echo "uploaded $(basename "$ARCHIVE") size=$SIZE"
