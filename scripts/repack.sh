#!/usr/bin/env bash
# Rebuild the image from the existing rootfs (no allsave).
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build.sh" --repack-only "$@"
