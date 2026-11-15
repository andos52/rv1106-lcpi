#!/usr/bin/env bash
# Shared helpers for the RV1106 project scripts.
#
# This file is sourced, never executed. Callers keep `set -euo pipefail`.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_SDK_DIR="${HOME}/rv1106-sdk/bort4g-radio"

JOY_NODE_ID="${JOY_NODE_ID:-251}"
JOY_SOURCE="${JOY_SOURCE:-pi4joy}"
JOY_IMAGE_NAME="${JOY_IMAGE_NAME:-lcpi-joy.img}"

LCPI_BASE_CFG="BoardConfig-SPI_NAND-Buildroot-RV1106_LCPI_RV1106-IPC.mk"
LCPI_JOY_CFG="BoardConfig-SPI_NAND-Buildroot-RV1106_LCPI_JOY-IPC.mk"
PRO_MAX_CFG="BoardConfig-SPI_NAND-Buildroot-RV1106_Luckfox_Pico_Pro_Max-IPC.mk"
LCPI_DTS="rv1106g-lcpi-rv1106.dts"

JOY_RADIO_SERVICES="S21appinit S39wifi S50usbdevice S60micinit S90usb-watchdog S96radiod S99usb0config S99hciinit"

die() { printf '%s: ERROR: %s\n' "${LOG_PREFIX:-rv1106}" "$*" >&2; exit 1; }
note() { printf '%s: %s\n' "${LOG_PREFIX:-rv1106}" "$*"; }
warn() { printf '%s: WARN: %s\n' "${LOG_PREFIX:-rv1106}" "$*" >&2; }

sdk_init() {
    SDK_DIR="${SDK_DIR:-$DEFAULT_SDK_DIR}"
    CFG_DIR="$SDK_DIR/project/cfg/BoardConfig_IPC"
    DTS_DIR="$SDK_DIR/sysdrv/source/kernel/arch/arm/boot/dts"
    KCFG="$SDK_DIR/sysdrv/source/kernel/arch/arm/configs/luckfox_rv1106_linux_defconfig"
    KSCRIPTS="$SDK_DIR/sysdrv/source/kernel/scripts/config"
    BR_ROOT="$SDK_DIR/sysdrv/source/buildroot"
    BR_DIR="$(find "$BR_ROOT" -maxdepth 1 -mindepth 1 -type d -name 'buildroot-*' 2>/dev/null | sort -V | tail -1)"
    BRCFG_DIR="${BR_DIR:+$BR_DIR/configs}"
    ROOTFS="$SDK_DIR/output/out/rootfs_uclibc_rv1106"
    OEM="$SDK_DIR/output/out/oem"
    UPDATE_IMG="$SDK_DIR/output/image/update.img"
    DIST="$PROJECT_ROOT/dist"
}

require_sdk() {
    [ -d "$SDK_DIR" ] || die "SDK not found: $SDK_DIR"
    [ -x "$SDK_DIR/build.sh" ] || die "SDK build.sh not found: $SDK_DIR/build.sh"
}

require_file() {
    [ -f "$1" ] || die "missing file: $1"
}

require_dir() {
    [ -d "$1" ] || die "missing directory: $1"
}

select_board() {
    local cfg="$1"
    [ -f "$CFG_DIR/$cfg" ] || die "board profile not found: $CFG_DIR/$cfg"
    ln -sfn "project/cfg/BoardConfig_IPC/$cfg" "$SDK_DIR/.BoardConfig.mk"
}

skip_media_samples() {
    local mk="$SDK_DIR/media/Makefile"
    [ -f "$mk" ] || return 0
    sed -i 's|^[[:space:]]*make -C ./samples$|# samples skipped: RockIVA headers not shipped|' "$mk"
}

fix_e2fs_dirs() {
    SDK_DIR="$SDK_DIR" bash "$PROJECT_ROOT/scripts/fix-e2fs-dirs.sh"
}

# Create the shared LCPI base profile and install the board DTS. Safe to call
# from both the radio and the joy preparation steps, including a fresh SDK.
ensure_lcpi_base() {
    require_file "$CFG_DIR/$PRO_MAX_CFG"
    require_file "$PROJECT_ROOT/board/dts/$LCPI_DTS"

    if [ ! -f "$CFG_DIR/$LCPI_BASE_CFG" ]; then
        note "creating base profile from Pro Max"
        cp "$CFG_DIR/$PRO_MAX_CFG" "$CFG_DIR/$LCPI_BASE_CFG"
    fi
    sed -i "s|$PRO_MAX_CFG|$LCPI_BASE_CFG|" "$CFG_DIR/$LCPI_BASE_CFG"
    sed -i "s|^export RK_KERNEL_DTS=.*|export RK_KERNEL_DTS=$LCPI_DTS|" "$CFG_DIR/$LCPI_BASE_CFG"
    sed -i 's|^export RK_BOOTARGS_CMA_SIZE=.*|export RK_BOOTARGS_CMA_SIZE="32M"|' "$CFG_DIR/$LCPI_BASE_CFG"
    sed -i 's|^export RK_APP_TYPE=.*|export RK_APP_TYPE=|' "$CFG_DIR/$LCPI_BASE_CFG"
    sed -i 's|^export RK_ENABLE_ROCKCHIP_TEST=.*|export RK_ENABLE_ROCKCHIP_TEST=n|' "$CFG_DIR/$LCPI_BASE_CFG"
    sed -i 's|^export RK_ENABLE_WIFI=.*|export RK_ENABLE_WIFI=n|' "$CFG_DIR/$LCPI_BASE_CFG"

    cp "$PROJECT_ROOT/board/dts/$LCPI_DTS" "$DTS_DIR/$LCPI_DTS"
    select_board "$LCPI_BASE_CFG"
    skip_media_samples
    fix_e2fs_dirs
}

# Force the previous Pi4Joy identity everywhere the image or runtime reads it.
apply_joy_identity() {
    local files
    files="$(find \
        "$SDK_DIR/media/out" \
        "$SDK_DIR/media/radiod/out" \
        "$SDK_DIR/media/radiod/defaults" \
        "$SDK_DIR/output/out" \
        -name radiod.conf -type f 2>/dev/null || true)"
    if [ -n "$files" ]; then
        while IFS= read -r f; do
            [ -n "$f" ] && sed -i "s/^node_id=.*/node_id=$JOY_NODE_ID/" "$f"
        done <<< "$files"
    fi
    if [ -f "$ROOTFS/etc/pi4joy/env" ]; then
        sed -i "s/^PI4JOY_NSU_SOURCE=.*/PI4JOY_NSU_SOURCE=$JOY_SOURCE/" "$ROOTFS/etc/pi4joy/env"
    fi
}

# Remove assets that the media build would otherwise put back into the image.
clean_radio_assets() {
    local f
    for f in \
        "$SDK_DIR/media/out/root/etc/init.d/S96radiod" \
        "$SDK_DIR/media/out/etc/init.d/S96radiod" \
        "$SDK_DIR/media/out/bin/S99unow-signal-diag" \
        "$SDK_DIR/media/radiod/out/root/etc/init.d/S96radiod" \
        "$SDK_DIR/media/radiod/out/etc/init.d/S96radiod" \
        "$SDK_DIR/media/unow/out/bin/S99unow-signal-diag" \
        "$SDK_DIR/output/out/media_out/root/etc/init.d/S96radiod" \
        "$SDK_DIR/output/out/media_out/etc/init.d/S96radiod" \
        "$SDK_DIR/output/out/media_out/bin/S99unow-signal-diag"; do
        rm -f "$f"
    done
    for f in "$SDK_DIR/media/radiod/scripts/S96radiod" "$SDK_DIR/media/unow/scripts/S99unow-signal-diag"; do
        if [ -f "$f" ]; then
            mv "$f" "$f.disabled"
        fi
    done
}

inject_joy_payload() {
    require_dir "$ROOTFS"
    require_file "$PROJECT_ROOT/firmware/pi4joy/opt/pi4joy/pi4joy"

    note "injecting pi4joy overlay"
    rsync -a "$PROJECT_ROOT/firmware/pi4joy/" "$ROOTFS/"
    chmod +x "$ROOTFS/opt/pi4joy/pi4joy" "$ROOTFS/etc/init.d/S95pi4joy"

    apply_joy_identity

    local static_if="$SDK_DIR/project/overlay/etc/init.d/S41eth0-static"
    require_file "$static_if"
    cp "$static_if" "$ROOTFS/etc/init.d/S41eth0-static"
    chmod +x "$ROOTFS/etc/init.d/S41eth0-static"

    local s
    for s in $JOY_RADIO_SERVICES; do
        rm -f "$ROOTFS/etc/init.d/$s"
    done
    rm -f "$OEM/etc/init.d/S96radiod" "$OEM/etc/init.d/S99unow-signal-diag"
    clean_radio_assets
}

repack_joy_image() {
    note "repacking firmware"
    ( cd "$SDK_DIR" && CMAKE_POLICY_VERSION_MINIMUM=3.5 ./build.sh firmware )
    require_file "$UPDATE_IMG"

    mkdir -p "$DIST"
    cp "$UPDATE_IMG" "$DIST/$JOY_IMAGE_NAME"
    ( cd "$DIST" && sha256sum "$JOY_IMAGE_NAME" > "$JOY_IMAGE_NAME.sha256" )
    note "image: $DIST/$JOY_IMAGE_NAME"
    cat "$DIST/$JOY_IMAGE_NAME.sha256"
}
