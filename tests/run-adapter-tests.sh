#!/usr/bin/env bash
# The adapter contract: four functions, every adapter honours the same
# shape. web.sh is exercised for real; the stub adapters (tui/desktop/mobile)
# only for their capability/refusal contract.
set -u
# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(dirname -- "$HERE")"
. "$HERE/_helper.sh"

sandbox
mkdir -p "$SANDBOX/src"
cat > "$SANDBOX/src/OrdersTable.tsx" <<'TSX'
export function OrdersTable() {
  return <table data-ui-id="UI-ORDERS-TABLE">
    <caption>Tabelle offener Bestellungen</caption>
  </table>;
}
TSX
mkdir -p "$SANDBOX/node_modules/somelib"
printf 'data-ui-id="UI-ORDERS-TABLE"\n' > "$SANDBOX/node_modules/somelib/decoy.tsx"

echo "== web adapter =="
. "$ROOT/plugin/scripts/adapters/web.sh"
check "globs include tsx" "1" "$(mb_adapter_globs | grep -c '\.tsx$')"
check "capabilities: structure=yes" "1" "$(mb_adapter_capabilities | grep -c '^structure=yes$')"
check "capabilities: visual=no" "1" "$(mb_adapter_capabilities | grep -c '^visual=no$')"
check "capabilities has exactly 7 keys" "7" "$(mb_adapter_capabilities | grep -c '=')"
check "token_sources has a css glob and a regex" "1" "$(mb_adapter_token_sources | grep -c '\.css')"
check "token_sources covers sass and scss" "2" "$(mb_adapter_token_sources | grep -cE '\*\.s[ac]ss')"
check "token_sources covers inline styles in tsx" "1" "$(mb_adapter_token_sources | grep -c '\*\.tsx')"
check "every token_sources line is glob<TAB>regex" "0" "$(mb_adapter_token_sources | grep -vc $'\t')"

check_rc "locate finds the marker (tier A)" 0 bash -c '. "$1/plugin/scripts/adapters/web.sh"; MB_ADAPTER_ROOT="$2" mb_adapter_locate UI-ORDERS-TABLE "Tabelle offener Bestellungen"' _ "$ROOT" "$SANDBOX"
OUT="$(MB_ADAPTER_ROOT="$SANDBOX" mb_adapter_locate UI-ORDERS-TABLE "Tabelle offener Bestellungen")"
check "tier A result present" "1" "$(printf '%s\n' "$OUT" | grep -c '^A	src/OrdersTable.tsx:2$')"
check "tier B (label match) present" "1" "$(printf '%s\n' "$OUT" | grep -c '^B	')"
check "node_modules excluded from locate" "0" "$(printf '%s\n' "$OUT" | grep -c 'node_modules')"
check_rc "no candidate anywhere -> exit 3" 3 bash -c '. "$1/plugin/scripts/adapters/web.sh"; MB_ADAPTER_ROOT="$2" mb_adapter_locate UI-NOWHERE ""' _ "$ROOT" "$SANDBOX/does-not-exist"

echo "== stub adapters (tui/desktop/mobile) =="
for name in tui desktop mobile; do
	unset -f mb_adapter_globs mb_adapter_locate mb_adapter_capabilities mb_adapter_token_sources 2>/dev/null
	# shellcheck disable=SC1090  # adapter path is intentionally dynamic (the loop variable)
	. "$ROOT/plugin/scripts/adapters/$name.sh"
	check "$name: all capabilities are no" "0" "$(mb_adapter_capabilities | grep -vc '=no$')"
	check_rc "$name: locate refuses (exit 3)" 3 mb_adapter_locate X ""
done
unset -f mb_adapter_globs mb_adapter_locate mb_adapter_capabilities mb_adapter_token_sources 2>/dev/null

summary "run-adapter-tests"
