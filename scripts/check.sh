#!/usr/bin/env bash
# Lightweight repository checks that do not need the SDK or a board.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

check_shell() {
    local f
    while IFS= read -r -d '' f; do
        if ! bash -n "$f"; then
            echo "syntax: FAIL $f" >&2
            fail=1
        fi
        if grep -q $'\r' "$f"; then
            echo "crlf: FAIL $f" >&2
            fail=1
        fi
    done < <(find "$ROOT/scripts" "$ROOT/overlay" "$ROOT/firmware" -type f \
        \( -name '*.sh' -o -path '*/etc/init.d/*' \) -print0)
}

check_python() {
    python3 -m py_compile "$ROOT/scripts/configure_image.py"
    python3 "$ROOT/scripts/configure_image.py" \
        --config "$ROOT/configs/image.example.json" --check
}

check_docs() {
    local required=(README.md VERSION docs/README.md docs/12-pi4joy.md docs/14-сеть-адреса.md)
    local f
    for f in "${required[@]}"; do
        [ -f "$ROOT/$f" ] || { echo "missing: $f" >&2; fail=1; }
    done
}

check_shell
check_python
check_docs

if [ "$fail" -ne 0 ]; then
    echo "check: FAILED" >&2
    exit 1
fi
echo "check: OK"
