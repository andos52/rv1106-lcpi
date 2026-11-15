#!/usr/bin/env bash
# Set the NSU source identity used by pi4joy.

set -euo pipefail
LOG_PREFIX="identity"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

sdk_init
require_sdk
apply_identity
note "source=$SOURCE node_ip=$NODE_IP"
