#!/usr/bin/env bash
# Build the Pi4Joy replacement image (LCPI_JOY): USB host/HID + eudev + pi4joy.
# Run inside WSL/Linux.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_DIR="${SDK_DIR:-$HOME/rv1106-sdk/bort4g-radio}"
DIST="$ROOT/dist"
ROOTFS="$SDK_DIR/output/out/rootfs_uclibc_rv1106"

die() { echo "build-joy: ERROR: $*" >&2; exit 1; }
note() { echo "build-joy: $*"; }

[ -x "$SDK_DIR/build.sh" ] || die "SDK not found: $SDK_DIR"
[ -f "$ROOT/firmware/pi4joy/opt/pi4joy/pi4joy" ] || die "pi4joy binary missing"

"$ROOT/scripts/prepare_joy.sh"

note "building SDK (allsave)"
( cd "$SDK_DIR" && CMAKE_POLICY_VERSION_MINIMUM=3.5 ./build.sh allsave )

[ -d "$ROOTFS" ] || die "rootfs staging not found: $ROOTFS"

note "injecting pi4joy overlay"
rsync -a "$ROOT/firmware/pi4joy/" "$ROOTFS/"
chmod +x "$ROOTFS/opt/pi4joy/pi4joy" "$ROOTFS/etc/init.d/S95pi4joy"

# Same identity as the previous pi4joy: 192.168.127.251, source "pi4joy".
OEM="$SDK_DIR/output/out/oem"
SDK_DIR="$SDK_DIR" sh "$ROOT/scripts/set_joy_identity.sh"
if [ -f "$OEM/etc/radiod.conf" ]; then
    sed -i 's/^node_id=.*/node_id=251/' "$OEM/etc/radiod.conf"
fi
sed -i 's/^PI4JOY_NSU_SOURCE=.*/PI4JOY_NSU_SOURCE=pi4joy/' "$ROOTFS/etc/pi4joy/env"
cp "$SDK_DIR/project/overlay/etc/init.d/S41eth0-static" "$ROOTFS/etc/init.d/S41eth0-static"
chmod +x "$ROOTFS/etc/init.d/S41eth0-static"

# Radio/gadget/camera services are not used on the joystick image.
for s in S21appinit S39wifi S50usbdevice S60micinit \
         S90usb-watchdog S96radiod S99usb0config S99hciinit; do
    rm -f "$ROOTFS/etc/init.d/$s"
done
rm -f "$OEM/etc/init.d/S96radiod" "$OEM/etc/init.d/S99unow-signal-diag"

note "repacking firmware"
( cd "$SDK_DIR" && ./build.sh firmware )

mkdir -p "$DIST"
cp "$SDK_DIR/output/image/update.img" "$DIST/lcpi-joy.img"
( cd "$DIST" && sha256sum lcpi-joy.img > lcpi-joy.img.sha256 )
note "image: $DIST/lcpi-joy.img"
cat "$DIST/lcpi-joy.img.sha256"
