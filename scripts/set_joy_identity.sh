#!/usr/bin/env bash
# Force the previous Pi4Joy identity in the SDK/image staging.

set -euo pipefail
LOG_PREFIX="set-joy-identity"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

sdk_init
require_sdk
apply_joy_identity
note "identity: node_id=$JOY_NODE_ID source=$JOY_SOURCE"
