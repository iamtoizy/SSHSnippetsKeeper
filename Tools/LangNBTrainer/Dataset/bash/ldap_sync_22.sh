#!/bin/bash
LDAP_SERVER="ldap://ldap.internal"
BASE_DN="ou=people,dc=corp,dc=internal"
BIND_USER="cn=sync,dc=corp,dc=internal"
BIND_PASS_FILE="/etc/ldap/sync.pass"
OUTPUT="data/ldap_users.csv"
PASS=$(cat "$BIND_PASS_FILE")
ldapsearch -x -H "$LDAP_SERVER" -D "$BIND_USER" -w "$PASS" \
    -b "$BASE_DN" "(objectClass=person)" uid mail employeeType > /tmp/ldap_raw.txt
if [ $? -ne 0 ]; then
    echo "ldapsearch failed" >&2
    exit 2
fi
echo "uid,mail,type" > "$OUTPUT"
awk "
    /^uid:/ {uid = \$2}
    /^mail:/ {mail = \$2}
    /^employeeType:/ {type = \$2}
    /^\$/ {
        if (uid != \"\") {
            printf \"%s,%s,%s\n\", uid, (mail == \"\" ? \"none\" : mail), (type == \"\" ? \"external\" : type)
        }
        uid = \"\"; mail = \"\"; type = \"\"
    }
" /tmp/ldap_raw.txt >> "$OUTPUT"
TOTAL=$(($(wc -l < "$OUTPUT") - 1))
echo "synced users: $TOTAL"
DUPLICATES=$(cut -d, -f1 "$OUTPUT" | tail -n +2 | sort | uniq -d | wc -l)
if [ "$DUPLICATES" -gt 0 ]; then
    echo "duplicate uids: $DUPLICATES" >&2
fi
EXTERNAL=$(grep -c ",external$" "$OUTPUT")
CONTRACTORS=$(grep -c ",contractor$" "$OUTPUT")
echo "external=$EXTERNAL contractors=$CONTRACTORS"
chown root:app "$OUTPUT"
chmod 640 "$OUTPUT"
rm -f /tmp/ldap_raw.txt
