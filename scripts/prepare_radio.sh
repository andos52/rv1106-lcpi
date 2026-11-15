#!/usr/bin/env bash
# Prepare the masha v1.8.0 radio profile for LCPI-RV1106 V1.4.
# AR9271 + ath9k_htc/ath9ku + radiod/ULAMA; no LTE/WireGuard.

set -euo pipefail
LOG_PREFIX="prepare-radio"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

sdk_init
require_sdk
ensure_lcpi_base

note "LCPI radio profile selected"
note "  config: $CFG_DIR/$LCPI_BASE_CFG"
note "  DTS:    $DTS_DIR/$LCPI_DTS"
note "  radio:  vcpd transport=radiod, mon0 ch6, node=1"
