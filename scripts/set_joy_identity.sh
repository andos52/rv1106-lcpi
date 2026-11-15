#!/bin/sh
# Force Pi4Joy identity on the board image: node_id=251 in every radiod.conf.
set -e
SDK="${SDK_DIR:-$HOME/rv1106-sdk/bort4g-radio}"
find "$SDK" -name radiod.conf -type f -exec sed -i 's/^node_id=.*/node_id=251/' {} +
find "$SDK" -name radiod.conf -type f -exec grep -H '^node_id=' {} +
