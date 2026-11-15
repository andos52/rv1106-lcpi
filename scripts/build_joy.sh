#!/usr/bin/env bash
# Build the Pi4Joy replacement image (LCPI_JOY).
#
#   build_joy.sh                 prepare + full SDK build + inject + repack
#   build_joy.sh --repack-only   reuse the existing rootfs, inject + repack
#   build_joy.sh --skip-prepare  do not touch the SDK profile first

set -euo pipefail
LOG_PREFIX="build-joy"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

REPACK_ONLY=0
SKIP_PREPARE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --repack-only) REPACK_ONLY=1; shift ;;
        --skip-prepare) SKIP_PREPARE=1; shift ;;
        -h|--help)
            cat <<'EOF'
Usage: build_joy.sh [--repack-only] [--skip-prepare]

  --repack-only   skip ./build.sh allsave and reuse output/out/rootfs*
  --skip-prepare  do not regenerate the LCPI_JOY profile
  -h, --help      this help

Environment: SDK_DIR, JOY_IMAGE_NAME, JOY_NODE_ID, JOY_SOURCE.
EOF
            exit 0
            ;;
        *) die "unknown option: $1" ;;
    esac
done

sdk_init
require_sdk
require_file "$PROJECT_ROOT/firmware/pi4joy/opt/pi4joy/pi4joy"

if [ "$SKIP_PREPARE" -eq 0 ]; then
    bash "$PROJECT_ROOT/scripts/prepare_joy.sh"
fi
if [ "$REPACK_ONLY" -eq 0 ]; then
    note "building SDK (allsave)"
    ( cd "$SDK_DIR" && CMAKE_POLICY_VERSION_MINIMUM=3.5 ./build.sh allsave )
fi

inject_joy_payload
repack_joy_image
