#!/usr/bin/env bash
# Insert or replace the mockingbird design block in a target document, using
# mb-render-block.sh's output. Thin CLI wrapper around mb_insert_block — the
# actual placement rules (above preflight's security block, idempotent no-op,
# damaged-block refusal) live in mockingbird-blocklib.sh, not here.
#
# Usage: mb-insert-block.sh <target-file> --root DIR [render args...]
# Exit codes are mb_insert_block's: 0 written · 2 damaged block, refused ·
# 3 missing file · 4 no-op, already up to date. Render/validation failures
# from mb-render-block.sh (2/3/6) pass through unchanged.
set -u
# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PLUGIN_ROOT="$(dirname -- "$HERE")"
. "$PLUGIN_ROOT/lib/mockingbird-blocklib.sh"

[ $# -ge 1 ] || { echo "usage: mb-insert-block.sh <target-file> --root DIR [render args...]" >&2; exit 2; }
TARGET="$1"; shift

TMP_BLOCK="$(mktemp)" || exit 1
trap 'rm -f -- "$TMP_BLOCK"' EXIT

"$HERE/mb-render-block.sh" "$@" > "$TMP_BLOCK"
rc=$?
# render's own error messages already went to stderr directly (only its
# stdout was captured here), so on failure there is nothing useful to relay
# from TMP_BLOCK -- just propagate the exit code.
[ "$rc" -eq 0 ] || exit "$rc"

mb_insert_block "$TARGET" "$TMP_BLOCK"
