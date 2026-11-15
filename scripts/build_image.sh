#!/usr/bin/env bash
# BRING-UP ONLY: build the luxfox-based test image (ULAMA/UDP placeholder).
# The target radio image is built from masha v1.8.0 (see docs/07, prepare_radio.sh).
# Configure overlay -> build SDK -> inject -> repack.
#
# Runs inside WSL/Linux (Ubuntu 22.04 recommended by the Rockchip/Luckfox SDK).
# The SDK is the public usalko/luxfox fork (see scripts/fetch-sdk.sh).

set -euo pipefail

# Host CMake 4.x (Ubuntu 26.04) rejects projects with cmake_minimum_required < 3.5.
export CMAKE_POLICY_VERSION_MINIMUM="${CMAKE_POLICY_VERSION_MINIMUM:-3.5}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_DIR="${SDK_DIR:-$HOME/rv1106-sdk/luxfox}"
CONFIG="${CONFIG:-$ROOT/configs/image.json}"
BUILD="$ROOT/build"
DIST="$ROOT/dist"
OVERLAY_ROOT="${OVERLAY_ROOT:-$SDK_DIR/output/out/rootfs_uclibc_rv1106}"
SKIP_INITIAL_BUILD=0
DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: scripts/build_image.sh [options]

  --config PATH        image config (default: configs/image.json)
  --sdk DIR            SDK checkout (default: $HOME/rv1106-sdk/luxfox)
  --overlay-root DIR   SDK rootfs root to inject into
                       (default: <sdk>/output/out/media_out/root)
  --skip-initial-build reuse an existing rootfs (faster iterations)
  --dry-run            validate prerequisites and print the plan only
  -h, --help           show this help

Environment: SDK_DIR, CONFIG, OVERLAY_ROOT.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --config) CONFIG="$2"; shift 2 ;;
        --sdk) SDK_DIR="$2"; shift 2 ;;
        --overlay-root) OVERLAY_ROOT="$2"; shift 2 ;;
        --skip-initial-build) SKIP_INITIAL_BUILD=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "build_image: unknown option: $1" >&2; usage; exit 2 ;;
    esac
done

die() { echo "build_image: ERROR: $*" >&2; exit 1; }
note() { echo "build_image: $*"; }

command -v python3 >/dev/null 2>&1 || die "python3 is required"
[ -f "$CONFIG" ] || die "config not found: $CONFIG"
[ -x "$SDK_DIR/build.sh" ] || die "SDK not found: $SDK_DIR (run scripts/fetch-sdk.sh)"

"$ROOT/scripts/prepare_board.sh"
python3 "$ROOT/scripts/configure_image.py" --config "$CONFIG" --out "$BUILD/image-overlay"
IMAGE_NAME="$(python3 "$ROOT/scripts/configure_image.py" --config "$CONFIG" --print-name)"
[ -n "$IMAGE_NAME" ] || die "cannot derive image name"

mkdir -p "$BUILD" "$DIST"

if [ "$DRY_RUN" -eq 1 ]; then
    note "dry run: plan"
    if [ "$SKIP_INITIAL_BUILD" -eq 0 ]; then
        note "  1. prepare_board.sh (profile lcpi_rv1106 + ath9k_htc)"
        note "  2. cd $SDK_DIR && ./build.sh allsave"
    fi
    note "  3. rsync -a $ROOT/overlay/ $OVERLAY_ROOT/"
    note "  4. rsync -a $BUILD/image-overlay/ $OVERLAY_ROOT/"
    note "  5. cd $SDK_DIR && ./build.sh firmware   # repack with overlay"
    note "  6. copy update.img -> $DIST/$IMAGE_NAME + .sha256"
    exit 0
fi

if [ "$SKIP_INITIAL_BUILD" -eq 0 ]; then
    note "building SDK firmware (first pass: allsave)"
    ( cd "$SDK_DIR" && ./build.sh allsave )
fi

[ -d "$OVERLAY_ROOT" ] || die "rootfs overlay target not found: $OVERLAY_ROOT (use --overlay-root)"
note "injecting static overlay"
rsync -a "$ROOT/overlay/" "$OVERLAY_ROOT/"
note "injecting generated config"
rsync -a "$BUILD/image-overlay/" "$OVERLAY_ROOT/"
chmod +x "$OVERLAY_ROOT/etc/init.d/S50wifi" "$OVERLAY_ROOT/etc/init.d/S60vcpd"

# Default image starts rkipc, radiod and USB gadget; not used by this board.
for s in S21appinit S96radiod S50usbdevice S99usb0config S90usb-watchdog S99hciinit; do
    rm -f "$OVERLAY_ROOT/etc/init.d/$s"
done

note "repacking firmware"
( cd "$SDK_DIR" && ./build.sh firmware )

UPDATE_IMG="$SDK_DIR/output/image/update.img"
[ -f "$UPDATE_IMG" ] || die "update.img not produced: $UPDATE_IMG"

cp "$UPDATE_IMG" "$DIST/$IMAGE_NAME"
( cd "$DIST" && sha256sum "$IMAGE_NAME" > "$IMAGE_NAME.sha256" )

note "image ready: $DIST/$IMAGE_NAME"
cat "$DIST/$IMAGE_NAME.sha256"
