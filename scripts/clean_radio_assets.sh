#!/usr/bin/env bash
# Remove radio/telemetry assets so the firmware repack does not reinstall them.
set -euo pipefail

SDK_DIR="${SDK_DIR:-$HOME/rv1106-sdk/bort4g-radio}"

for f in \
    "$SDK_DIR/media/out/root/etc/init.d/S96radiod" \
    "$SDK_DIR/media/out/etc/init.d/S96radiod" \
    "$SDK_DIR/media/out/bin/S99unow-signal-diag" \
    "$SDK_DIR/media/radiod/out/root/etc/init.d/S96radiod" \
    "$SDK_DIR/media/radiod/out/etc/init.d/S96radiod" \
    "$SDK_DIR/media/unow/out/bin/S99unow-signal-diag" \
    "$SDK_DIR/output/out/media_out/root/etc/init.d/S96radiod" \
    "$SDK_DIR/output/out/media_out/etc/init.d/S96radiod" \
    "$SDK_DIR/output/out/media_out/bin/S99unow-signal-diag"; do
    rm -f "$f"
done

# Prevent a future media rebuild from putting them back.
for f in "$SDK_DIR/media/radiod/scripts/S96radiod" "$SDK_DIR/media/unow/scripts/S99unow-signal-diag"; do
    [ -f "$f" ] && mv "$f" "$f.disabled"
done

echo "clean-radio-assets: done"
