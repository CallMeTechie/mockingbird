#!/usr/bin/env bash
# mb-render-block.sh and mb-insert-block.sh: rendering a manifest into a block,
# and placing that block into a target document.
set -u
# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(dirname -- "$HERE")"
. "$HERE/_helper.sh"
. "$ROOT/plugin/lib/mockingbird-blocklib.sh"
. "$ROOT/plugin/lib/mockingbird-manifestlib.sh"
. "$ROOT/plugin/hooks/mockingbird-hooklib.sh"

RENDER="$ROOT/plugin/scripts/mb-render-block.sh"
INSERT="$ROOT/plugin/scripts/mb-insert-block.sh"

sandbox
PROJ="$SANDBOX/proj"
mkdir -p "$PROJ/.git" "$PROJ/docs/design/mockups"
cp "$ROOT/tests/fixtures/manifest/valid.yaml" "$PROJ/docs/design/manifest.yaml"
printf '# design system\n' > "$PROJ/docs/design/design-system.md"
: > "$PROJ/docs/design/mockups/index.html"
: > "$PROJ/docs/design/mockups/tokens.css"
: > "$PROJ/docs/design/mockups/ui-orders.html"
: > "$PROJ/docs/design/mockups/ui-shell.html"

echo "== mb-render-block.sh =="
check_rc "usage error without --root" 2 "$RENDER"
check_rc "missing manifest -> 3" 3 "$RENDER" --root "$SANDBOX/nowhere"

BLOCK="$("$RENDER" --root "$PROJ")"
check_rc "renders successfully" 0 "$RENDER" --root "$PROJ"
check "starts with begin marker" "$MB_DESIGN_BEGIN" "$(printf '%s\n' "$BLOCK" | head -n1)"
check "ends with end marker" "$MB_DESIGN_END" "$(printf '%s\n' "$BLOCK" | tail -n1)"
check "includes all four elements" "4" "$(printf '%s\n' "$BLOCK" | grep -cE '^\| UI-')"
check "not: clause renders readably" "1" "$(printf '%s\n' "$BLOCK" | grep -c 'Nicht: invoice, shipment\.')"

echo "== rendered block validates against its own contract =="
printf '%s\n' "$BLOCK" > "$SANDBOX/block.md"
check_rc "well-formed marker pair" 0 mb_design_block_state "$SANDBOX/block.md"
check_rc "facts comment is valid" 0 mb_design_facts_valid "$SANDBOX/block.md"
DHASH="$(mb_fact_get "$(mb_design_facts_raw "$SANDBOX/block.md")" design_hash)"
check "facts hash matches mb_design_hash" "sha256:$(mb_design_hash "$PROJ")" "$DHASH"

echo "== --screens filters the table, --consumes adds the prose list =="
SUB="$("$RENDER" --root "$PROJ" --screens UI-ORDERS --consumes UI-SHELL-NAV)"
check "screens filter drops UI-SHELL-NAV row" "0" "$(printf '%s\n' "$SUB" | grep -cE '^\| UI-SHELL-NAV ')"
check "screens filter keeps UI-ORDERS rows" "3" "$(printf '%s\n' "$SUB" | grep -cE '^\| UI-ORDERS')"
check "consumed element listed in prose with its label" "1" "$(printf '%s\n' "$SUB" | grep -cF -- '`UI-SHELL-NAV` — Hauptnavigation')"
check "facts screens= reflects the filter" "UI-ORDERS" "$(mb_fact_get "$(printf '%s\n' "$SUB" | grep '<!-- design:')" screens)"
check "facts consumes= reflects the flag" "UI-SHELL-NAV" "$(mb_fact_get "$(printf '%s\n' "$SUB" | grep '<!-- design:')" consumes)"

echo "== manifest fails validation -> render refuses =="
BAD="$SANDBOX/bad-proj"; mkdir -p "$BAD/docs/design"
sed 's/UI-ORDERS-EMPTY/UI-ORDERS-TABLE/' "$PROJ/docs/design/manifest.yaml" > "$BAD/docs/design/manifest.yaml"
check_rc "invalid manifest -> 6, nothing rendered" 6 "$RENDER" --root "$BAD"

echo "== mb-insert-block.sh: placement, idempotence, propagation of render failures =="
SPEC="$SANDBOX/spec.md"
printf '# Orders Spec\n\nBefore.\n' > "$SPEC"
check_rc "first insert writes (0)" 0 "$INSERT" "$SPEC" --root "$PROJ"
check "prose preserved" "1" "$(grep -cF 'Before.' "$SPEC")"
check "block present" "1" "$(grep -cF -- "$MB_DESIGN_BEGIN" "$SPEC")"
check_rc "second insert is a no-op (4)" 4 "$INSERT" "$SPEC" --root "$PROJ"
cp "$SPEC" "$SANDBOX/spec-after-first.md"
check_rc "no-op did not modify the file" 0 diff -q "$SANDBOX/spec-after-first.md" "$SPEC"

SPEC2="$SANDBOX/spec-with-security.md"
{
	printf '# Orders Spec\n\nProse.\n\n<!-- preflight:security:begin -->\n'
	printf '<!-- facts: x=1 -->\n\n## Security Requirements\n<!-- preflight:security:end -->\n'
} > "$SPEC2"
check_rc "insert alongside a security block" 0 "$INSERT" "$SPEC2" --root "$PROJ"
DL="$(grep -nF -- "$MB_DESIGN_BEGIN" "$SPEC2" | head -1 | cut -d: -f1)"
SL="$(grep -nF -- '<!-- preflight:security:begin -->' "$SPEC2" | head -1 | cut -d: -f1)"
check_rc "design block precedes the security block" 0 test "$DL" -lt "$SL"

DAMAGED="$SANDBOX/damaged.md"
printf '%s\n%s\n%s\n' "$MB_DESIGN_BEGIN" "$MB_DESIGN_BEGIN" "$MB_DESIGN_END" > "$DAMAGED"
cp "$DAMAGED" "$SANDBOX/damaged-before.md"
check_rc "damaged block refused (2)" 2 "$INSERT" "$DAMAGED" --root "$PROJ"
check_rc "damaged file left untouched" 0 diff -q "$SANDBOX/damaged-before.md" "$DAMAGED"

check_rc "render failure (bad manifest) propagates as 6" 6 "$INSERT" "$SPEC" --root "$BAD"
check_rc "render usage error propagates as 2" 2 "$INSERT" "$SPEC"

summary "run-render-tests"
