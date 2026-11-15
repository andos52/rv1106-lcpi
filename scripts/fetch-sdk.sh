#!/usr/bin/env bash
# Fetch the Rockchip RV1106 SDK fork used as the firmware base.
# Run inside WSL/Linux (not on the Windows filesystem: case-sensitive paths).

set -euo pipefail

SDK_DIR="${SDK_DIR:-$HOME/rv1106-sdk/luxfox}"
REPO="${REPO:-https://github.com/usalko/luxfox.git}"

if [ -d "$SDK_DIR/.git" ]; then
    echo "fetch-sdk: already present: $SDK_DIR"
    git -C "$SDK_DIR" rev-parse --short HEAD
    exit 0
fi

mkdir -p "$(dirname "$SDK_DIR")"
echo "fetch-sdk: cloning $REPO -> $SDK_DIR (about 1 GB)"
git clone --depth 1 --single-branch "$REPO" "$SDK_DIR"
git -C "$SDK_DIR" rev-parse --short HEAD
echo "fetch-sdk: done"
