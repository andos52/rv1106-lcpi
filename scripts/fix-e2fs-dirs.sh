#!/bin/sh
# Work around e2fsprogs 1.46.5 with coreutils 9.x (Ubuntu 26.04): its MKDIR_P
# does not honor DESTDIR, so pre-create the destination directories.
# Idempotent; safe to run before any build.

SDK="${SDK_DIR:-$HOME/rv1106-sdk/bort4g-radio}"
BR_ROOT="$SDK/sysdrv/source/buildroot"
BR="$(find "$BR_ROOT" -maxdepth 1 -mindepth 1 -type d -name 'buildroot-*' 2>/dev/null | sort -V | tail -1)"
BR="${BR:-$BR_ROOT/buildroot-2023.02.6}"
HOST="$(find "$BR/output/host" -maxdepth 1 -mindepth 1 -type d -name 'arm-*' 2>/dev/null | head -1)"
HOST="${HOST:-$BR/output/host/arm-buildroot-linux-uclibcgnueabihf}"
SYSROOT="$HOST/sysroot"
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
