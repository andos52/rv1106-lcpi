#!/usr/bin/env bash
# Create the LCPI-RV1106 board profile in the SDK from the closest Luckfox
# profile (Pico Pro Max: SPI NAND 256MB, SC3336, Ethernet) and enable the
# AR9271 USB Wi-Fi driver.
#
# Run inside WSL/Linux. Idempotent.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_DIR="${SDK_DIR:-$HOME/rv1106-sdk/luxfox}"

CFG_DIR="$SDK_DIR/project/cfg/BoardConfig_IPC"
DTS_DIR="$SDK_DIR/sysdrv/source/kernel/arch/arm/boot/dts"
KCFG="$SDK_DIR/sysdrv/source/kernel/arch/arm/configs/luckfox_rv1106_linux_defconfig"

SRC_CFG="$CFG_DIR/BoardConfig-SPI_NAND-Buildroot-RV1106_Luckfox_Pico_Pro_Max-IPC.mk"
DST_CFG="$CFG_DIR/BoardConfig-SPI_NAND-Buildroot-RV1106_LCPI_RV1106-IPC.mk"
SRC_DTS="$DTS_DIR/rv1106g-luckfox-pico-pro-max.dts"
DST_DTS="$DTS_DIR/rv1106g-lcpi-rv1106.dts"

die() { echo "prepare-board: ERROR: $*" >&2; exit 1; }
note() { echo "prepare-board: $*"; }

[ -d "$SDK_DIR" ] || die "SDK not found: $SDK_DIR"
[ -f "$SRC_CFG" ] || die "source profile not found: $SRC_CFG"
[ -f "$SRC_DTS" ] || die "source DTS not found: $SRC_DTS"

note "creating board config"
cp "$SRC_CFG" "$DST_CFG"
sed -i 's|BoardConfig-SPI_NAND-Buildroot-RV1106_Luckfox_Pico_Pro_Max-IPC.mk|BoardConfig-SPI_NAND-Buildroot-RV1106_LCPI_RV1106-IPC.mk|' "$DST_CFG"
sed -i 's|rv1106g-luckfox-pico-pro-max.dts|rv1106g-lcpi-rv1106.dts|' "$DST_CFG"
# AR9271 is handled by the in-kernel ath9k_htc; skip vendor Wi-Fi drivers
# (aic8800_usb currently fails to build with this toolchain).
if ! grep -q RK_ENABLE_WIFI_CHIP "$DST_CFG"; then
    printf '\nexport RK_ENABLE_WIFI_CHIP="NONE"\n' >> "$DST_CFG"
fi
# rkipc demo needs RockIVA/freetype headers that are not shipped; the video
# pipeline uses vcpd from media/, so skip the app build.
sed -i 's|^export RK_APP_TYPE=.*|export RK_APP_TYPE=|' "$DST_CFG"

note "creating board DTS"
cp "$SRC_DTS" "$DST_DTS"
sed -i 's|model = "Luckfox Pico Pro Max";|model = "LC Technology LCPI-RV1106 V1.4";|' "$DST_DTS"
sed -i 's|"rockchip,rv1106g3"|"rockchip,rv1106g2"|' "$DST_DTS"
sed -i 's|dr_mode = "peripheral";|dr_mode = "otg";|' "$DST_DTS"

note "selecting board profile (.BoardConfig.mk -> LCPI)"
ln -sfn "project/cfg/BoardConfig_IPC/$(basename "$DST_CFG")" "$SDK_DIR/.BoardConfig.mk"

note "enabling AR9271 (ath9k_htc) in kernel defconfig"
for opt in CFG80211 MAC80211 ATH_COMMON ATH9K_HTC; do
    "$SDK_DIR/sysdrv/source/kernel/scripts/config" --file "$KCFG" -m "$opt"
done

for fw in htc_9271.fw ath9k_htc/htc_9271-1.4.0.fw; do
    [ -f "$ROOT/overlay/lib/firmware/$fw" ] || die "firmware missing: overlay/lib/firmware/$fw"
done

# Media samples need RockIVA headers, which are not shipped in this SDK.
sed -i 's|^[[:space:]]*make -C ./samples$|# samples skipped: RockIVA headers not shipped|' "$SDK_DIR/media/Makefile"

# Ubuntu 26.04 uses coreutils 9.x; e2fsprogs 1.46.5 install expects
# destination dirs to exist and fails with "install: invalid target".
sh "$ROOT/scripts/fix-e2fs-dirs.sh"

note "done"
note "  config: $DST_CFG"
note "  DTS:    $DST_DTS"
note "  USB:    dr_mode=otg"
note "  Wi-Fi:  ath9k_htc (AR9271) + firmware"
