#!/usr/bin/env bash
# Prepare the LCPI_JOY profile (Pi4Joy replacement) in the masha v1.8.0 SDK.
# USB host + HID, eudev for /dev/input/by-path, CMA 32M.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_DIR="${SDK_DIR:-$HOME/rv1106-sdk/bort4g-radio}"
CFG_DIR="$SDK_DIR/project/cfg/BoardConfig_IPC"
DTS_DIR="$SDK_DIR/sysdrv/source/kernel/arch/arm/boot/dts"
KCFG="$SDK_DIR/sysdrv/source/kernel/arch/arm/configs/luckfox_rv1106_linux_defconfig"
BRCFG_DIR="$SDK_DIR/sysdrv/source/buildroot/buildroot-2023.02.6/configs"

SRC_CFG="$CFG_DIR/BoardConfig-SPI_NAND-Buildroot-RV1106_LCPI_RV1106-IPC.mk"
DST_CFG="$CFG_DIR/BoardConfig-SPI_NAND-Buildroot-RV1106_LCPI_JOY-IPC.mk"
SRC_DTS="$ROOT/board/dts/rv1106g-lcpi-rv1106.dts"
DST_DTS="$DTS_DIR/rv1106g-lcpi-rv1106.dts"
BR_SRC="$BRCFG_DIR/luckfox_pico_defconfig"
BR_DST="$BRCFG_DIR/luckfox_pico_joy_defconfig"

die() { echo "prepare-joy: ERROR: $*" >&2; exit 1; }
note() { echo "prepare-joy: $*"; }

[ -d "$SDK_DIR" ] || die "SDK not found: $SDK_DIR"
[ -f "$SRC_CFG" ] || die "LCPI profile not found: $SRC_CFG"

note "DTS: USB host mode"
cp "$SRC_DTS" "$DST_DTS"

note "kernel: DWC3 host + HID/evdev"
for opt in USB_DWC3 USB_DWC3_HOST USB_XHCI_HCD USB_EHCI_HCD USB_HID HID_GENERIC INPUT_EVDEV; do
    "$SDK_DIR/sysdrv/source/kernel/scripts/config" --file "$KCFG" -e "$opt"
done
"$SDK_DIR/sysdrv/source/kernel/scripts/config" --file "$KCFG" -d USB_DWC3_DUAL_ROLE
"$SDK_DIR/sysdrv/source/kernel/scripts/config" --file "$KCFG" -d USB_DWC3_GADGET

note "Buildroot: eudev for by-path"
cp "$BR_SRC" "$BR_DST"
sed -i '/BR2_ROOTFS_DEVICE_CREATION_STATIC=y/d;/BR2_ROOTFS_DEVICE_CREATION_DYNAMIC_MDEV=y/d;/BR2_ROOTFS_DEVICE_CREATION_DYNAMIC_DEVTMPFS=y/d;/BR2_ROOTFS_DEVICE_CREATION_DYNAMIC_EUDEV=y/d;/BR2_PACKAGE_EUDEV=y/d' "$BR_DST"
cat >> "$BR_DST" <<'EOF'
BR2_ROOTFS_DEVICE_CREATION_DYNAMIC_EUDEV=y
BR2_PACKAGE_EUDEV=y
EOF

note "board profile LCPI_JOY"
cp "$SRC_CFG" "$DST_CFG"
sed -i 's|BoardConfig-SPI_NAND-Buildroot-RV1106_LCPI_RV1106-IPC.mk|BoardConfig-SPI_NAND-Buildroot-RV1106_LCPI_JOY-IPC.mk|' "$DST_CFG"
sed -i 's|^export RK_BUILDROOT_DEFCONFIG=.*|export RK_BUILDROOT_DEFCONFIG=luckfox_pico_joy_defconfig|' "$DST_CFG"
sed -i 's|^export RK_BOOTARGS_CMA_SIZE=.*|export RK_BOOTARGS_CMA_SIZE="32M"|' "$DST_CFG"

note "select LCPI_JOY"
ln -sfn "project/cfg/BoardConfig_IPC/$(basename "$DST_CFG")" "$SDK_DIR/.BoardConfig.mk"

note "pi4joy env"
if [ ! -f "$ROOT/firmware/pi4joy/etc/pi4joy/env" ]; then
    cp "$ROOT/firmware/pi4joy/etc/pi4joy/env.example" "$ROOT/firmware/pi4joy/etc/pi4joy/env"
fi

note "done"
note "  profile: $DST_CFG"
note "  buildroot: luckfox_pico_joy_defconfig (eudev)"
note "  DTS: dr_mode=host, CMA 32M"
