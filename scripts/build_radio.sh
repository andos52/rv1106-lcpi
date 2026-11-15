#!/usr/bin/env bash
# Build the masha radio drone image (camera + AR9271 + radiod/ULAMA).
#
#   build_radio.sh                 prepare + full SDK build + repack
#   build_radio.sh --repack-only   reuse existing rootfs, repack only
#   build_radio.sh --skip-prepare  do not touch the SDK profile first

set -euo pipefail
LOG_PREFIX="build-radio"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

REPACK_ONLY=0
SKIP_PREPARE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --repack-only) REPACK_ONLY=1; shift ;;
        --skip-prepare) SKIP_PREPARE=1; shift ;;
        -h|--help)
            cat <<'EOF'
Usage: build_radio.sh [--repack-only] [--skip-prepare]

  --repack-only   skip ./build.sh allsave and reuse output/out/rootfs*
  --skip-prepare  do not regenerate the LCPI radio profile
  -h, --help      this help

Environment: SDK_DIR, RADIO_IMAGE_NAME, RADIO_NODE_ID.
EOF
            exit 0
            ;;
        *) die "unknown option: $1" ;;
    esac
done

sdk_init
require_sdk

if [ "$SKIP_PREPARE" -eq 0 ]; then
    bash "$PROJECT_ROOT/scripts/prepare_radio.sh"
fi

if [ "$REPACK_ONLY" -eq 0 ]; then
    note "building SDK (allsave)"
    ( cd "$SDK_DIR" && CMAKE_POLICY_VERSION_MINIMUM=3.5 ./build.sh allsave )
fi

require_dir "$ROOTFS"

# A previous joy build may have swapped media sources and installed pi4joy.
restore_radio_assets
apply_radio_identity
clean_joy_assets

for f in "$ROOTFS/etc/init.d/S39wifi" "$ROOTFS/etc/init.d/S96radiod"; do
    [ -f "$f" ] || warn "radio init script missing in rootfs: $f"
done

note "repacking firmware"
( cd "$SDK_DIR" && CMAKE_POLICY_VERSION_MINIMUM=3.5 ./build.sh firmware )
require_file "$UPDATE_IMG"

mkdir -p "$DIST"
cp "$UPDATE_IMG" "$DIST/$RADIO_IMAGE_NAME"
( cd "$DIST" && sha256sum "$RADIO_IMAGE_NAME" > "$RADIO_IMAGE_NAME.sha256" )
note "image: $DIST/$RADIO_IMAGE_NAME (node_id=$RADIO_NODE_ID)"
cat "$DIST/$RADIO_IMAGE_NAME.sha256"
