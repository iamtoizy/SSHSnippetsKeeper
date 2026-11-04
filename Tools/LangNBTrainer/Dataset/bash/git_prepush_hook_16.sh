#!/bin/bash
REMOTE="$1"
ZERO="0000000000000000000000000000000000000000"
while read -r LOCAL REMOTE_LOCAL REMOTE_REF REMOTE_REMOTE; do
    if [ "$REMOTE_LOCAL" = "$ZERO" ]; then
        continue
    fi
    BRANCH="${REMOTE_REF#refs/heads/}"
    case "$BRANCH" in
        main|master)
            if git log --oneline origin/main..HEAD | grep -qiE "wip|tmp|fixme"; then
                echo "refusing work-in-progress commits for $BRANCH" >&2
                exit 1
            fi
            ;;
    esac
    BIG_FILES=$(git diff --stat "$REMOTE_REMOTE".."$REMOTE_LOCAL" 2>/dev/null | awk "\$3 ~ /M/ && \$1+0 > 5 {print \$2}")
    if [ -n "$BIG_FILES" ]; then
        echo "files over 5MB detected:" >&2
        echo "$BIG_FILES" >&2
        exit 1
    fi
    SECRET_HITS=$(git diff "$REMOTE_REMOTE".."$REMOTE_LOCAL" | grep -cE "(api_key|password|BEGIN RSA PRIVATE)")
    if [ "$SECRET_HITS" -gt 0 ]; then
        echo "possible secrets in commit range" >&2
        exit 1
    fi
    AUTHOR=$(git log -1 --format="%ae" "$REMOTE_LOCAL")
    if ! echo "$AUTHOR" | grep -q "@example.com$"; then
        echo "author email $AUTHOR is not allowed" >&2
        exit 1
    fi
done
FILES=$(git diff --name-only @{push}..HEAD 2>/dev/null | wc -l)
echo "pushing $FILES changed files to $REMOTE"
exit 0
