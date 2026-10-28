#!/bin/bash
TEMPLATE_DIR="/etc/app/templates"
OUTPUT_DIR="/etc/app/generated"
ENV_FILE="/etc/app/env.conf"
set -a
source "$ENV_FILE"
set +a
mkdir -p "$OUTPUT_DIR"
render() {
    local TEMPLATE="$1"
    local TARGET="$2"
    sed -e "s|{{HOSTNAME}}|$HOSTNAME|g" \
        -e "s|{{LISTEN_PORT}}|$LISTEN_PORT|g" \
        -e "s|{{DB_HOST}}|$DB_HOST|g" \
        -e "s|{{CACHE_SIZE}}|$CACHE_SIZE|g" \
        -e "s|{{RUN_DATE}}|$(date +%F)|g" \
        "$TEMPLATE_DIR/$TEMPLATE" > "$OUTPUT_DIR/$TARGET"
}
for TPL in "$TEMPLATE_DIR"/*.tmpl; do
    NAME=$(basename "$TPL" .tmpl)
    render "$NAME.tmpl" "$NAME.conf" || {
        echo "render failed for $NAME" >&2
        continue
    }
    UNRENDERED=$(grep -c "{{" "$OUTPUT_DIR/$NAME.conf" || true)
    if [ "$UNRENDERED" -gt 0 ]; then
        echo "$NAME: $UNRENDERED placeholders left" >&2
        grep -o "{{[A-Z_]*}}" "$OUTPUT_DIR/$NAME.conf" | sort -u
    fi
done
app_configtest 2>/dev/null || nginx -t
CHECKSUM=$(sha256sum "$OUTPUT_DIR"/*.conf | md5sum | cut -c1-8)
echo "rendered checksum: $CHECKSUM"
systemctl reload app-logger
logger -t template_render "configs regenerated $CHECKSUM"
