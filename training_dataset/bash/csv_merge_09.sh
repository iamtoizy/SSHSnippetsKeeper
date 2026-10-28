#!/bin/bash
USERS_CSV="data/users.csv"
ORDERS_CSV="data/orders.csv"
OUTPUT="data/report.csv"
sort -t, -k1,1 "$USERS_CSV" > /tmp/users.sorted
sort -t, -k2,2 "$ORDERS_CSV" > /tmp/orders.sorted
join -t, -1 1 -2 2 /tmp/users.sorted /tmp/orders.sorted > /tmp/joined.csv
awk -F, '
    NR == 1 {next}
    {
        region[$2] += $4
        orders[$2]++
    }
    END {
        for (r in region) {
            printf "%s,%d,%.2f\n", r, orders[r], region[r]
        }
    }
' /tmp/joined.csv | sort -t, -k3,3nr > "$OUTPUT"
HEADER="region,orders,total"
sed -i "1i $HEADER" "$OUTPUT"
TOTAL=$(awk -F, 'NR>1 {s += $3} END {print s}' "$OUTPUT")
ROWS=$(($(wc -l < "$OUTPUT") - 1))
echo "rows=$ROWS total=$TOTAL"
awk -F, '$3 == 0 {print $1}' "$OUTPUT" | tee /tmp/empty_regions.txt
EMPTY=$(wc -l < /tmp/empty_regions.txt)
if [ "$EMPTY" -gt 0 ]; then
    echo "empty regions: $EMPTY" >&2
fi
sed -n '2,10p' "$OUTPUT"
rm -f /tmp/users.sorted /tmp/orders.sorted /tmp/joined.csv /tmp/empty_regions.txt
