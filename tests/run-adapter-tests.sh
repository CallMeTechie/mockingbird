#!/usr/bin/env bash
# The adapter contract: five functions, every adapter honours the same
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
printf 'export const M = () => <ContextMenu dataUiId="UI-ORDERS-MENU" />;\n' > "$SANDBOX/src/Menu.tsx"
printf 'export const N = () => <ContextMenu dataUiId={"UI-ORDERS-MENU2"} />;\n' > "$SANDBOX/src/Menu2.tsx"
check "camelCase prop dataUiId counts as tier A" "1" "$(MB_ADAPTER_ROOT="$SANDBOX" mb_adapter_locate UI-ORDERS-MENU "" | grep -c '^A	src/Menu.tsx:1$')"
check "dataUiId in braces counts too" "1" "$(MB_ADAPTER_ROOT="$SANDBOX" mb_adapter_locate UI-ORDERS-MENU2 "" | grep -c '^A	src/Menu2.tsx:1$')"
printf 'const other = "UI-ORDERS-MENU";\n' > "$SANDBOX/src/NotAMarker.tsx"
check "a bare string that is not a marker is not tier A" "0" "$(MB_ADAPTER_ROOT="$SANDBOX" mb_adapter_locate UI-ORDERS-MENU "" | grep -c '^A.*NotAMarker')"
check "tier B (label match) present" "1" "$(printf '%s\n' "$OUT" | grep -c '^B	')"
check "node_modules excluded from locate" "0" "$(printf '%s\n' "$OUT" | grep -c 'node_modules')"
echo "== web adapter: healthcheck =="
mkdir -p "$SANDBOX/client" "$SANDBOX/landing"
cat > "$SANDBOX/client/package.json" <<'PKG'
{ "name": "c", "scripts": { "dev": "vite", "lint": "eslint .", "build": "vite build" } }
PKG
cat > "$SANDBOX/landing/package.json" <<'PKG'
{ "name": "l", "scripts": { "build": "astro build" } }
PKG
HC="$(mb_adapter_healthcheck "$SANDBOX")"
# A repo-wide lint on an existing codebase is red before mockingbird touches
# anything, so lint is file-scoped and names the tool directly: an npm script
# "eslint ." cannot be narrowed by appending a path.
check "lint is file-scoped and names the tool" "1" "$(printf '%s\n' "$HC" | grep -c '^client	npx eslint	files$')"
check "build stays whole-package" "1" "$(printf '%s\n' "$HC" | grep -c '^client	npm run --silent build	whole$')"
check "healthcheck skips scripts the project lacks" "0" "$(printf '%s\n' "$HC" | grep -c 'typecheck')"
check "no lint invented for a package without one" "0" "$(printf '%s\n' "$HC" | grep -c '^landing	npx')"
check "every line is workdir<TAB>command<TAB>scope" "0" "$(printf '%s\n' "$HC" | grep -vcE $'^[^\t]+	[^\t]+	(whole|files)$')"
# "dev" must never be offered: running it starts a server that never exits.
check "never offers a long-running script" "0" "$(printf '%s\n' "$HC" | grep -c 'dev')"
# An unknown linter cannot be narrowed safely, so it falls back to whole.
cat > "$SANDBOX/client/package.json" <<'PKG'
{ "name": "c", "scripts": { "lint": "./tools/mylint --all" } }
PKG
check "an unrecognised linter falls back to whole-package" "1" "$(mb_adapter_healthcheck "$SANDBOX" | grep -c '^client	npm run --silent lint	whole$')"
cat > "$SANDBOX/client/package.json" <<'PKG'
{ "name": "c", "dependencies": { "lint": "1.0.0" } }
PKG
check "a dependency named like a script is not a command" "0" "$(mb_adapter_healthcheck "$SANDBOX" | grep -c '^client	')"

check_rc "no candidate anywhere -> exit 3" 3 bash -c '. "$1/plugin/scripts/adapters/web.sh"; MB_ADAPTER_ROOT="$2" mb_adapter_locate UI-NOWHERE ""' _ "$ROOT" "$SANDBOX/does-not-exist"

echo "== stub adapters (tui/desktop/mobile) =="
for name in tui desktop mobile; do
	unset -f mb_adapter_globs mb_adapter_locate mb_adapter_capabilities mb_adapter_token_sources mb_adapter_healthcheck 2>/dev/null
	# shellcheck disable=SC1090  # adapter path is intentionally dynamic (the loop variable)
	. "$ROOT/plugin/scripts/adapters/$name.sh"
	check "$name: all capabilities are no" "0" "$(mb_adapter_capabilities | grep -vc '=no$')"
	check_rc "$name: locate refuses (exit 3)" 3 mb_adapter_locate X ""
	check "$name: healthcheck is silent" "" "$(mb_adapter_healthcheck "$SANDBOX")"
done
unset -f mb_adapter_globs mb_adapter_locate mb_adapter_capabilities mb_adapter_token_sources mb_adapter_healthcheck 2>/dev/null

summary "run-adapter-tests"
