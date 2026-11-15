#!/usr/bin/env bash
# Print RV1106 build progress and selected profile.
# Usage: status.sh [recent-minutes]   (SDK_DIR=... to inspect another SDK)

set -euo pipefail
LOG_PREFIX="status"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

sdk_init
MIN="${1:-5}"

echo "=== sdk ==="
echo "$SDK_DIR"
if [ -L "$SDK_DIR/.BoardConfig.mk" ]; then
    echo "profile: $(readlink "$SDK_DIR/.BoardConfig.mk" | xargs basename 2>/dev/null || true)"
fi

echo "=== build process ==="
PID=$(pgrep -f "build.sh" | head -1 || true)
if [ -n "$PID" ]; then
    echo "RUNNING pid=$PID elapsed=$(ps -o etime= -p "$PID" | tr -d ' ')"
else
    echo "not running (finished or stopped)"
fi
pgrep -af "make|gcc|cc1|buildroot" | grep -v pgrep | head -6 || true

echo "=== stages ==="
check() {
    if [ -f "$1" ]; then
        echo "DONE  $2  ($(date -r "$1" '+%H:%M:%S'))"
    else
        echo "WAIT  $2"
    fi
}
check "$SDK_DIR/output/image/uboot.img" "U-Boot"
check "$SDK_DIR/output/image/boot.img" "Kernel/boot"
if [ -f "$SDK_DIR/output/image/rootfs.img" ]; then
    echo "DONE  Rootfs  ($(date -r "$SDK_DIR/output/image/rootfs.img" '+%H:%M:%S'))"
elif [ -f "$SDK_DIR/output/image/rootfs.ubifs" ]; then
    echo "DONE  Rootfs  ($(date -r "$SDK_DIR/output/image/rootfs.ubifs" '+%H:%M:%S'))"
else
    echo "WAIT  Rootfs"
fi
check "$UPDATE_IMG" "update.img (final)"

echo "=== files changed in last ${MIN} min ==="
find "$SDK_DIR/output" -type f -mmin "-$MIN" 2>/dev/null | tail -10 || true

echo "=== output size ==="
du -sh "$SDK_DIR/output" 2>/dev/null || true
