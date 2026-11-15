#!/usr/bin/env bash
# Prepare the bort4g (masha production) SDK copy for the LCPI-RV1106 board.
# Variant A: LAN/LTE uplink + WireGuard, no board-side Wi-Fi.
#
# Run inside WSL/Linux. Idempotent.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_DIR="${SDK_DIR:-$HOME/rv1106-sdk/bort4g-lcpi}"

CFG_DIR="$SDK_DIR/project/cfg/BoardConfig_IPC"
DTS_DIR="$SDK_DIR/sysdrv/source/kernel/arch/arm/boot/dts"

SRC_CFG="$CFG_DIR/BoardConfig-EMMC-Buildroot-RV1106_Luckfox_Pico_Ultra-IPC.mk"
DST_CFG="$CFG_DIR/BoardConfig-SPI_NAND-Buildroot-RV1106_LCPI_RV1106-IPC.mk"
DST_DTS="$DTS_DIR/rv1106g-lcpi-rv1106.dts"
SRC_DTS="$ROOT/board/dts/rv1106g-lcpi-rv1106.dts"

die() { echo "prepare-bort4g: ERROR: $*" >&2; exit 1; }
note() { echo "prepare-bort4g: $*"; }

[ -d "$SDK_DIR" ] || die "bort4g copy not found: $SDK_DIR"
[ -f "$SRC_CFG" ] || die "source profile not found: $SRC_CFG"
[ -f "$SRC_DTS" ] || die "LCPI DTS not found: $SRC_DTS"

note "creating LCPI board config from Ultra profile"
cp "$SRC_CFG" "$DST_CFG"
sed -i 's|BoardConfig-EMMC-Buildroot-RV1106_Luckfox_Pico_Ultra-IPC.mk|BoardConfig-SPI_NAND-Buildroot-RV1106_LCPI_RV1106-IPC.mk|' "$DST_CFG"
sed -i 's|^export RK_BOOT_MEDIUM=.*|export RK_BOOT_MEDIUM=spi_nand|' "$DST_CFG"
sed -i 's|^export RK_KERNEL_DTS=.*|export RK_KERNEL_DTS=rv1106g-lcpi-rv1106.dts|' "$DST_CFG"
sed -i 's|^export RK_UBOOT_DEFCONFIG_FRAGMENT=.*|export RK_UBOOT_DEFCONFIG_FRAGMENT="rk-sfc.config"|' "$DST_CFG"
sed -i 's|^export RK_PARTITION_CMD_IN_ENV=.*|export RK_PARTITION_CMD_IN_ENV="256K(env),256K@256K(idblock),512K(uboot),4M(boot),30M(oem),10M(userdata),210M(rootfs)"|' "$DST_CFG"
sed -i 's|^export RK_PARTITION_FS_TYPE_CFG=.*|export RK_PARTITION_FS_TYPE_CFG=rootfs@IGNORE@ubifs,userdata@/userdata@ubifs,oem@/oem@ubifs|' "$DST_CFG"
sed -i 's|^export RK_BOOTARGS_CMA_SIZE=.*|export RK_BOOTARGS_CMA_SIZE="32M"|' "$DST_CFG"
sed -i 's|^export RK_APP_TYPE=.*|export RK_APP_TYPE=|' "$DST_CFG"
sed -i 's|^export RK_ENABLE_ROCKCHIP_TEST=.*|export RK_ENABLE_ROCKCHIP_TEST=n|' "$DST_CFG"
sed -i 's|^export RK_MISC=.*|# export RK_MISC=wipe_all-misc.img|' "$DST_CFG"

note "installing LCPI DTS"
cp "$SRC_DTS" "$DST_DTS"

note "selecting profile"
ln -sfn "project/cfg/BoardConfig_IPC/$(basename "$DST_CFG")" "$SDK_DIR/.BoardConfig.mk"

note "skipping media samples (RockIVA headers absent)"
sed -i 's|^[[:space:]]*make -C ./samples$|# samples skipped: RockIVA headers not shipped|' "$SDK_DIR/media/Makefile"

note "creating e2fsprogs install dirs"
SDK_DIR="$SDK_DIR" sh "$ROOT/scripts/fix-e2fs-dirs.sh"

note "done"
note "  config: $DST_CFG"
note "  DTS:    $DST_DTS"
note "  video:  vcpd transport=ip (masha), peer 10.10.10.2:5600, UVCP 5601"
