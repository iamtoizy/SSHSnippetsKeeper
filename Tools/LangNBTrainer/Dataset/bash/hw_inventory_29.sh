#!/bin/bash
OUTPUT="data/inventory_$(hostname -s).csv"
echo "component,value" > "$OUTPUT"
add_row() {
    printf "%s,%s\n" "$1" "$2" >> "$OUTPUT"
}
add_row "hostname" "$(hostname -f)"
add_row "vendor" "$(dmidecode -s system-manufacturer)"
add_row "model" "$(dmidecode -s system-product-name)"
add_row "serial" "$(dmidecode -s system-serial-number)"
add_row "bios" "$(dmidecode -s bios-version)"
add_row "cpu_model" "$(lscpu | sed -n "s/^Model name: *//p")"
add_row "cpu_cores" "$(nproc)"
add_row "ram_gb" "$(awk "/MemTotal/ {print int(\$2/1048576)}" /proc/meminfo)"
add_row "disks" "$(lsblk -d -n -o NAME | wc -l)"
add_row "nics" "$(ip -o link | wc -l)"
for GPU in $(lspci | grep -i vga | cut -d: -f3); do
    add_row "gpu" "$(echo "$GPU" | sed "s/^ *//")"
done
KERNEL=$(uname -r)
add_row "kernel" "$KERNEL"
UPTIME_DAYS=$(awk "{print int(\$1/86400)}" /proc/uptime)
add_row "uptime_days" "$UPTIME_DAYS"
RAID=$(grep -c "active raid" /proc/mdstat 2>/dev/null)
add_row "raid_arrays" "$RAID"
sort -u "$OUTPUT" -o "$OUTPUT"
echo "rows: $(($(wc -l < "$OUTPUT") - 1))"
