#!/usr/bin/env bash
# Prepare the LCPI_JOY board profile: USB host/HID, eudev, CMA 32M.

set -euo pipefail
LOG_PREFIX="prepare"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

sdk_init
require_sdk
ensure_lcpi_base

note "installing LCPI DTS (USB host)"
cp "$PROJECT_ROOT/board/dts/$LCPI_DTS" "$DTS_DIR/$LCPI_DTS"

note "kernel: DWC3 host + HID/evdev"
require_file "$KCFG"
for opt in USB_DWC3 USB_DWC3_HOST USB_XHCI_HCD USB_EHCI_HCD USB_HID HID_GENERIC INPUT_EVDEV; do
    "$KSCRIPTS" --file "$KCFG" -e "$opt"
done
"$KSCRIPTS" --file "$KCFG" -d USB_DWC3_DUAL_ROLE
"$KSCRIPTS" --file "$KCFG" -d USB_DWC3_GADGET

note "Buildroot: eudev for /dev/input/by-path"
require_dir "$BRCFG_DIR"
BR_SRC="$BRCFG_DIR/luckfox_pico_defconfig"
BR_DST="$BRCFG_DIR/luckfox_pico_joy_defconfig"
require_file "$BR_SRC"
cp "$BR_SRC" "$BR_DST"
sed -i '/BR2_ROOTFS_DEVICE_CREATION_STATIC=y/d;/BR2_ROOTFS_DEVICE_CREATION_DYNAMIC_MDEV=y/d;/BR2_ROOTFS_DEVICE_CREATION_DYNAMIC_DEVTMPFS=y/d;/BR2_ROOTFS_DEVICE_CREATION_DYNAMIC_EUDEV=y/d;/BR2_PACKAGE_EUDEV=y/d' "$BR_DST"
cat >> "$BR_DST" <<'EOF'
BR2_ROOTFS_DEVICE_CREATION_DYNAMIC_EUDEV=y
BR2_PACKAGE_EUDEV=y
EOF

note "board profile LCPI_JOY"
cp "$CFG_DIR/$LCPI_BASE_CFG" "$CFG_DIR/$LCPI_JOY_CFG"
sed -i "s|$LCPI_BASE_CFG|$LCPI_JOY_CFG|" "$CFG_DIR/$LCPI_JOY_CFG"
sed -i 's|^export RK_BUILDROOT_DEFCONFIG=.*|export RK_BUILDROOT_DEFCONFIG=luckfox_pico_joy_defconfig|' "$CFG_DIR/$LCPI_JOY_CFG"
sed -i 's|^export RK_BOOTARGS_CMA_SIZE=.*|export RK_BOOTARGS_CMA_SIZE="32M"|' "$CFG_DIR/$LCPI_JOY_CFG"
select_board "$LCPI_JOY_CFG"

if [ ! -f "$PROJECT_ROOT/firmware/pi4joy/etc/pi4joy/env" ]; then
    cp "$PROJECT_ROOT/firmware/pi4joy/etc/pi4joy/env.example" "$PROJECT_ROOT/firmware/pi4joy/etc/pi4joy/env"
fi

note "done: $CFG_DIR/$LCPI_JOY_CFG"
