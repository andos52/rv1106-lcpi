#!/usr/bin/env bash
# Prepare the radio-era masha (v1.8.0) worktree for the LCPI-RV1106 board.
# Radio path: AR9271 USB stick + ath9k_htc/ath9ku + radiod/ULAMA; no LTE/WG.
#
# Run inside WSL/Linux. Idempotent.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_DIR="${SDK_DIR:-$HOME/rv1106-sdk/bort4g-radio}"

CFG_DIR="$SDK_DIR/project/cfg/BoardConfig_IPC"
DTS_DIR="$SDK_DIR/sysdrv/source/kernel/arch/arm/boot/dts"

SRC_CFG="$CFG_DIR/BoardConfig-SPI_NAND-Buildroot-RV1106_Luckfox_Pico_Pro_Max-IPC.mk"
DST_CFG="$CFG_DIR/BoardConfig-SPI_NAND-Buildroot-RV1106_LCPI_RV1106-IPC.mk"
SRC_DTS="$ROOT/board/dts/rv1106g-lcpi-rv1106.dts"
DST_DTS="$DTS_DIR/rv1106g-lcpi-rv1106.dts"

die() { echo "prepare-radio: ERROR: $*" >&2; exit 1; }
note() { echo "prepare-radio: $*"; }

[ -d "$SDK_DIR" ] || die "radio SDK not found: $SDK_DIR"
[ -f "$SRC_CFG" ] || die "source profile not found: $SRC_CFG"
[ -f "$SRC_DTS" ] || die "LCPI DTS not found: $SRC_DTS"

note "creating LCPI board config from Pro Max SPI NAND"
cp "$SRC_CFG" "$DST_CFG"
sed -i 's|BoardConfig-SPI_NAND-Buildroot-RV1106_Luckfox_Pico_Pro_Max-IPC.mk|BoardConfig-SPI_NAND-Buildroot-RV1106_LCPI_RV1106-IPC.mk|' "$DST_CFG"
sed -i 's|^export RK_KERNEL_DTS=.*|export RK_KERNEL_DTS=rv1106g-lcpi-rv1106.dts|' "$DST_CFG"
sed -i 's|^export RK_BOOTARGS_CMA_SIZE=.*|export RK_BOOTARGS_CMA_SIZE="32M"|' "$DST_CFG"
sed -i 's|^export RK_APP_TYPE=.*|export RK_APP_TYPE=|' "$DST_CFG"
sed -i 's|^export RK_ENABLE_ROCKCHIP_TEST=.*|export RK_ENABLE_ROCKCHIP_TEST=n|' "$DST_CFG"
# Vendor Wi-Fi (aic8800) is not used: radio is AR9271 via ath9k_htc/ath9ku
# modules shipped in project/overlay/oem/usr/ko.
sed -i 's|^export RK_ENABLE_WIFI=.*|export RK_ENABLE_WIFI=n|' "$DST_CFG"

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
note "  radio:  vcpd transport=radiod, mon0 ch6, node=1"
