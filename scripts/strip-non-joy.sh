#!/usr/bin/env bash
# Strip non-joystick services from the joy rootfs staging.

set -euo pipefail
LOG_PREFIX="strip"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

sdk_init
require_sdk
strip_non_joy_assets
note "done"
