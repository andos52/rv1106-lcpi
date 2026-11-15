#!/usr/bin/env bash
# Repository checks that do not need the SDK or a board.
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
    done < <(find "$ROOT/scripts" "$ROOT/firmware" -type f \
        \( -name '*.sh' -o -path '*/etc/init.d/*' \) -print0)
}

check_docs() {
    local required=(README.md VERSION docs/README.md
        docs/01-плата.md docs/02-архитектура.md docs/03-api-contract.md
        docs/04-сеть.md docs/05-чеклист.md docs/06-диагностика.md
        docs/07-сборка.md docs/08-прошивка.md docs/09-журнал.md)
    local f
    for f in "${required[@]}"; do
        [ -f "$ROOT/$f" ] || { echo "missing: $f" >&2; fail=1; }
    done
    # The project is joystick-only: keep hardware/feature references out of docs.
    if grep -RniE 'камер|camera|радио|radio|AR9271|vcpd|radiod' "$ROOT/docs" >/tmp/joy-docs-forbidden 2>/dev/null; then
        echo "docs: forbidden camera/radio references:" >&2
        cat /tmp/joy-docs-forbidden >&2
        fail=1
    fi
}

check_shell
check_docs

if [ "$fail" -ne 0 ]; then
    echo "check: FAILED" >&2
    exit 1
fi
echo "check: OK"
