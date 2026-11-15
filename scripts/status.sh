#!/bin/sh
# Print RV1106 build progress. Usage: status.sh [recent-minutes]

SDK="${SDK_DIR:-$HOME/rv1106-sdk/bort4g-radio}"
MIN="${1:-5}"

echo "=== build process ==="
PID=$(pgrep -f "build.sh" | head -1)
if [ -n "$PID" ]; then
    echo "RUNNING pid=$PID elapsed=$(ps -o etime= -p "$PID" | tr -d ' ')"
else
    echo "not running (finished or stopped)"
fi
pgrep -af "make|gcc|cc1|buildroot" | grep -v pgrep | head -6

echo "=== stages ==="
check() {
    if [ -f "$1" ]; then
        echo "DONE  $2  ($(date -r "$1" '+%H:%M:%S'))"
    else
        echo "WAIT  $2"
    fi
}
check "$SDK/output/image/uboot.img"   "U-Boot"
check "$SDK/output/image/boot.img"    "Kernel/boot"
if [ -f "$SDK/output/image/rootfs.img" ]; then
    echo "DONE  Rootfs  ($(date -r "$SDK/output/image/rootfs.img" '+%H:%M:%S'))"
elif [ -f "$SDK/output/image/rootfs.ubifs" ]; then
    echo "DONE  Rootfs  ($(date -r "$SDK/output/image/rootfs.ubifs" '+%H:%M:%S'))"
else
    echo "WAIT  Rootfs"
fi
check "$SDK/output/image/update.img"  "update.img (final)"

echo "=== files changed in last ${MIN} min ==="
find "$SDK/output" -type f -mmin "-$MIN" 2>/dev/null | tail -10

echo "=== output size ==="
du -sh "$SDK/output" 2>/dev/null
