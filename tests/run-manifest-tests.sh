#!/usr/bin/env bash
# The manifest layer: the strict-subset parser (mockingbird-manifest.awk),
# its TSV normal form, and semantic validation on top of it.
set -u
# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(dirname -- "$HERE")"
. "$HERE/_helper.sh"
. "$ROOT/plugin/lib/mockingbird-manifestlib.sh"

sandbox
FIX="$ROOT/tests/fixtures/manifest"
VALID="$FIX/valid.yaml"

# mutate <output-name> <sed-expr...> — copy valid.yaml, apply sed edits, return the path.
mutate() {
	local out="$SANDBOX/$1"; shift
	cp "$VALID" "$out"
	sed -i "$@" "$out"
	printf '%s' "$out"
}
# strip_lines <output-name> <start-pattern> <end-pattern> — delete a line range.
strip_block() {
	local out="$SANDBOX/$1" start="$2" end="$3"
	sed "/$start/,/$end/d" "$VALID" > "$out"
	printf '%s' "$out"
}

echo "== mb_manifest_to_tsv: shape and content =="
TSV="$(mb_manifest_to_tsv "$VALID")"
check "one line per element" "4" "$(printf '%s\n' "$TSV" | wc -l | tr -d ' ')"
check "18 tab separated fields" "18" "$(printf '%s' "$TSV" | head -n1 | awk -F'\t' '{print NF}')"
ROW="$(printf '%s\n' "$TSV" | grep -F 'UI-ORDERS-TABLE')"
check "screen id" "UI-ORDERS" "$(mb_tsv_field "$ROW" "$MB_F_SCREEN_ID")"
check "element type" "table" "$(mb_tsv_field "$ROW" "$MB_F_ELEMENT_TYPE")"
check "semantic means present" "Eine Zeile je Bestellung mit Status ungleich versendet." "$(mb_tsv_field "$ROW" "$MB_F_SEMANTIC_MEANS")"
check "aliases joined" "orders,bestellung" "$(mb_tsv_field "$ROW" "$MB_F_SEMANTIC_ALIASES")"
check "not joined" "invoice,shipment" "$(mb_tsv_field "$ROW" "$MB_F_SEMANTIC_NOT")"
check "states include empty and error" "default,loading,empty,error" "$(mb_tsv_field "$ROW" "$MB_F_STATES")"
check "locator with embedded quotes intact" "[data-ui-id='UI-ORDERS-TABLE']" "$(mb_tsv_field "$ROW" "$MB_F_LOCATOR_WEB")"
DROW="$(printf '%s\n' "$TSV" | grep -F 'UI-ORDERS-EXPORT')"
check "deferred_reason captured" "(2026-09-03) erst nach dem ersten Kundenfeedback" "$(mb_tsv_field "$DROW" "$MB_F_DEFERRED_REASON")"
check "skip reason captured" "(2026-09-03) noch nicht gebaut" "$(mb_tsv_field "$DROW" "$MB_F_SKIP_REASON")"
check "missing file -> 3" "3" "$(mb_manifest_to_tsv "$SANDBOX/nope.yaml" >/dev/null 2>&1; echo $?)"
check "screen uses: captured on every element of that screen" "UI-SHELL-NAV" "$(mb_tsv_field "$ROW" "$MB_F_SCREEN_USES")"
check "screen without uses: -> -" "-" "$(printf '%s\n' "$TSV" | awk -F'\t' -v c="$MB_F_SCREEN_USES" '$4=="UI-SHELL-NAV"{print $c}')"

echo "== mb_manifest_allocations =="
ALLOC="$(mb_manifest_allocations "$VALID")"
check "one allocation line" "1" "$(printf '%s\n' "$ALLOC" | grep -c .)"
check "allocation spec path" "docs/superpowers/specs/2026-09-03-orders-design.md" "$(printf '%s\n' "$ALLOC" | cut -f1)"
check "allocation owns" "UI-ORDERS,UI-SHELL" "$(printf '%s\n' "$ALLOC" | cut -f2)"
check "allocation empty consumes -> -" "-" "$(printf '%s\n' "$ALLOC" | cut -f3)"
NOALLOC="$SANDBOX/noalloc.yaml"; sed '/^allocations:/,/^retired:/{/^retired:/!d}' "$VALID" > "$NOALLOC"
check "no allocations -> empty" "" "$(mb_manifest_allocations "$NOALLOC")"

echo "== fence in an unrelated markdown-ish comment does not confuse the parser =="
# (documents that this parser only ever reads .yaml — no fence handling needed
# here, unlike the block lib. This case just proves a stray '#' comment line
# inside the block does not break anything, since '#'-led lines are blank.)
F="$SANDBOX/withcomment.yaml"
{ cat "$VALID"; printf '\n# just a trailing comment\n'; } > "$F"
check_rc "trailing comment does not error" 0 mb_manifest_to_tsv "$F" >/dev/null

echo "== mb_manifest_meta =="
META="$(mb_manifest_meta "$VALID")"
check "schema" "mockingbird/1" "$(printf '%s\n' "$META" | awk -F'\t' '$1=="schema"{print $2}')"
check "revision" "3" "$(printf '%s\n' "$META" | awk -F'\t' '$1=="revision"{print $2}')"
check "primary_adapter" "web" "$(printf '%s\n' "$META" | awk -F'\t' '$1=="primary_adapter"{print $2}')"
check "flow-collections excluded (retired)" "0" "$(printf '%s\n' "$META" | grep -c '^retired')"
check "changelog block excluded" "0" "$(printf '%s\n' "$META" | grep -c '^changelog')"

echo "== mb_valid_id =="
check_rc "screen id ok" 0 mb_valid_id "UI-ORDERS"
check_rc "element id ok" 0 mb_valid_id "UI-ORDERS-TABLE-01"
check_rc "lowercase rejected" 1 mb_valid_id "ui-orders"
check_rc "no prefix rejected" 1 mb_valid_id "ORDERS"
check_rc "too many segments rejected" 1 mb_valid_id "UI-A-B-C-D-E"
check_rc "too long rejected" 1 mb_valid_id "UI-$(printf 'A%.0s' $(seq 1 40))"

echo "== mb_manifest_validate: the parser-error path =="
BROKEN="$SANDBOX/broken.yaml"
printf 'schema: mockingbird/1\nscreens:\n  - id: UI-X\n    elements:\n      - id: UI-X-A\n        type: text\n   this line has odd indent\n' > "$BROKEN"
check_rc "malformed subset -> 5" 5 mb_manifest_validate "$BROKEN"

echo "== mb_manifest_validate: negative fixtures, one rule at a time =="
check_rc "valid manifest passes" 0 mb_manifest_validate "$VALID"

F="$(mutate dup.yaml -e 's/UI-ORDERS-EMPTY/UI-ORDERS-TABLE/')"
check_rc "duplicate element id" 6 mb_manifest_validate "$F"

F="$(mutate badid.yaml -e 's/UI-ORDERS-TABLE/orders-table/g')"
check_rc "id grammar violated" 6 mb_manifest_validate "$F"

F="$(strip_block noanchor.yaml 'semantic_anchor:' 'not: \[invoice, shipment\]')"
check_rc "data-bearing element without semantic_anchor" 6 mb_manifest_validate "$F"

F="$(mutate nodefault.yaml -e "/{ id: default }/d")"
check_rc "states list without default" 6 mb_manifest_validate "$F"

F="$(mutate badstatus.yaml -e 's/status: required/status: urgent/')"
check_rc "unknown status value" 6 mb_manifest_validate "$F"

F="$(mutate badverify.yaml -e 's/verify: required/verify: maybe/')"
check_rc "unknown verify value" 6 mb_manifest_validate "$F"

F="$(mutate deferrednoreason.yaml -e '/deferred_reason:/d')"
check_rc "deferred status without deferred_reason" 6 mb_manifest_validate "$F"

F="$(mutate skipnoreason.yaml -e '/^        reason:/d')"
check_rc "verify skip without reason" 6 mb_manifest_validate "$F"

F="$VALID"
MB_VALIDATE_ROOT="$SANDBOX" check_rc "missing artboard (with MB_VALIDATE_ROOT)" 6 mb_manifest_validate "$F"
mkdir -p "$SANDBOX/docs/design/mockups"
touch "$SANDBOX/docs/design/mockups/ui-orders.html" "$SANDBOX/docs/design/mockups/ui-shell.html"
MB_VALIDATE_ROOT="$SANDBOX" check_rc "present artboard (with MB_VALIDATE_ROOT)" 0 mb_manifest_validate "$F"
check_rc "no MB_VALIDATE_ROOT skips artboard check" 0 mb_manifest_validate "$F"

check_rc "missing manifest file" 3 mb_manifest_validate "$SANDBOX/nope.yaml"

echo "== cross-references: uses:/allocations must point at real ids =="
F="$(mutate badusesref.yaml -e 's/uses: \[UI-SHELL-NAV\]/uses: [UI-GHOST]/')"
check_rc "uses: unknown id" 6 mb_manifest_validate "$F"
F="$(mutate badallocref.yaml -e 's/owns: \[UI-ORDERS, UI-SHELL\]/owns: [UI-ORDERS, UI-NOPE]/')"
check_rc "allocations owns unknown id" 6 mb_manifest_validate "$F"

summary "run-manifest-tests"
