#!/usr/bin/env bash
# Backwards-compatible wrapper: rebuild the image from the existing rootfs.
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build_joy.sh" --repack-only "$@"
