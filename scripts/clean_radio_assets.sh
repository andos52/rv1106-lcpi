#!/usr/bin/env bash
# Remove radio/telemetry assets that the media build would reinstall.

set -euo pipefail
LOG_PREFIX="clean-radio-assets"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

sdk_init
require_sdk
clean_radio_assets
note "done"
