#!/bin/bash
MODE="${1:-encrypt}"
SRC_DIR="/srv/secrets"
ARCHIVE="/var/backups/secrets-$(date +%F).tar.gz.enc"
KEY_FILE="/etc/backup/archive.key"
encrypt_archive() {
    tar -czf - -C "$(dirname "$SRC_DIR")" "$(basename "$SRC_DIR")" |
        openssl enc -aes-256-cbc -pbkdf2 -salt -inkey "$KEY_FILE" -out "$ARCHIVE"
    sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"
    echo "encrypted archive: $ARCHIVE"
    du -h "$ARCHIVE" | awk "{print \"size:\", \$1}"
}
decrypt_archive() {
    local TARGET="${2:-/tmp/secrets_restore}"
    openssl enc -d -aes-256-cbc -pbkdf2 -inkey "$KEY_FILE" -in "$ARCHIVE" |
        tar -xzf - -C "$TARGET"
    echo "restored to $TARGET"
}
verify_archive() {
    sha256sum -c "$ARCHIVE.sha256" && echo "checksum ok" || echo "checksum mismatch" >&2
    openssl enc -d -aes-256-cbc -pbkdf2 -inkey "$KEY_FILE" -in "$ARCHIVE" |
        tar -tzf - | head -n 5
}
case "$MODE" in
    encrypt)
        encrypt_archive
        ;;
    decrypt)
        decrypt_archive "$@"
        ;;
    verify)
        verify_archive
        ;;
    *)
        echo "usage: $0 {encrypt|decrypt|verify}" >&2
        exit 64
        ;;
esac
find /var/backups -name "secrets-*.tar.gz.enc" -mtime +30 -delete
