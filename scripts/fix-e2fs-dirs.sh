#!/bin/sh
# Work around e2fsprogs 1.46.5 install with coreutils 9.x (Ubuntu 26.04):
# its MKDIR_P does not honor DESTDIR, so pre-create destination dirs.
# Idempotent; safe to run before any build.

SDK="${SDK_DIR:-$HOME/rv1106-sdk/luxfox}"
BR="$SDK/sysdrv/source/buildroot/buildroot-2023.02.6"
SYSROOT="$BR/output/host/arm-buildroot-linux-uclibcgnueabihf/sysroot"
TARGET="$BR/output/target"

DIRS="usr/lib usr/lib/pkgconfig usr/bin usr/sbin etc \
    usr/include usr/include/et usr/include/ss usr/include/e2p \
    usr/include/ext2 usr/include/ext2fs usr/include/uuid usr/include/blkid \
    usr/share usr/share/et usr/share/ss usr/share/info \
    usr/share/man usr/share/man/man1 usr/share/man/man3 \
    usr/share/man/man5 usr/share/man/man8 sbin bin"

LOCALES="ca cs da de eo es fi fr hu id it ms nl pl pt sr sv tr uk vi zh_CN"

for root in "$SYSROOT" "$TARGET"; do
    for d in $DIRS; do
        mkdir -p "$root/$d"
    done
done

for loc in $LOCALES; do
    mkdir -p "$TARGET/usr/share/locale/$loc/LC_MESSAGES"
done

echo "fix-e2fs-dirs: OK ($SYSROOT, $TARGET)"
