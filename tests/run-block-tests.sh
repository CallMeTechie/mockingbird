#!/usr/bin/env bash
# The design marker block: marker detection with fence filtering, the four-state
# exit contract, facts validation, and insertion next to preflight's own block.
set -u
# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(dirname -- "$HERE")"
. "$HERE/_helper.sh"
. "$ROOT/plugin/lib/mockingbird-blocklib.sh"

sandbox
SEC_BEGIN='<!-- preflight:security:begin -->'
SEC_END='<!-- preflight:security:end -->'
MB_BEGIN='<!-- mockingbird:design:begin -->'
MB_END='<!-- mockingbird:design:end -->'
GOOD_FACTS='<!-- design: manifest=docs/design/manifest.yaml design_rev=3 design_hash=sha256:'"$(printf 'a%.0s' $(seq 64))"' system=docs/design/design-system.md index=docs/design/mockups/index.html adapter=web screens=UI-ORDERS,UI-SHELL -->'

echo "== mb_design_block_state: the four-state contract =="
F="$SANDBOX/a.md"
printf '# Spec\n\nNo block here.\n' > "$F"
check_rc "no markers -> 1" 1 mb_design_block_state "$F"
check_rc "missing file -> 3" 3 mb_design_block_state "$SANDBOX/nope.md"
printf '# Spec\n\n%s\n%s\n' "$MB_BEGIN" "$MB_END" > "$F"
check_rc "one clean pair -> 0" 0 mb_design_block_state "$F"
printf '# Spec\n\n%s\n' "$MB_BEGIN" > "$F"
check_rc "one-sided -> 2" 2 mb_design_block_state "$F"
printf '# Spec\n\n%s\n%s\n%s\n%s\n' "$MB_END" "$MB_BEGIN" "$MB_END" "$MB_BEGIN" > "$F"
check_rc "duplicated -> 2" 2 mb_design_block_state "$F"
printf '# Spec\n\n%s\n%s\n' "$MB_END" "$MB_BEGIN" > "$F"
check_rc "reversed -> 2" 2 mb_design_block_state "$F"

echo "== fence filtering: documenting the format is not having a block =="
# This plugin's own spec quotes the markers in a fenced example. Without fence
# filtering that spec would classify as damaged and every run would abort.
{
	printf '# Spec\n\nThe block looks like this:\n\n'
	printf '```markdown\n%s\n%s\n```\n\n' "$MB_BEGIN" "$MB_END"
	printf 'Prose mention of %s in a sentence.\n' "$MB_BEGIN"
} > "$F"
check_rc "fenced + prose example -> 1" 1 mb_design_block_state "$F"
# A real block plus a fenced example is still exactly one block.
{
	printf '```markdown\n%s\n%s\n```\n\n' "$MB_BEGIN" "$MB_END"
	printf '%s\n%s\n' "$MB_BEGIN" "$MB_END"
} > "$F"
check_rc "example + real block -> 0" 0 mb_design_block_state "$F"
# An unterminated fence hides the real markers. Reporting "no block" here would
# make the writer append a SECOND block below the first one.
{
	printf '```markdown\n'
	printf '%s\n%s\n' "$MB_BEGIN" "$MB_END"
} > "$F"
check_rc "block hidden by open fence -> 2" 2 mb_design_block_state "$F"

echo "== mb_fact_get =="
RAW='manifest=docs/design/manifest.yaml design_rev=3 adapter=web'
check "reads a key" "web" "$(mb_fact_get "$RAW" adapter)"
check "reads first key" "docs/design/manifest.yaml" "$(mb_fact_get "$RAW" manifest)"
check_rc "unknown key fails" 1 mb_fact_get "$RAW" nope
# A value holding a glob character must never be expanded against the cwd.
check "glob value not expanded" 'a*' "$(mb_fact_get 'adapter=a*' adapter)"

echo "== mb_design_facts_valid =="
mkfacts() { printf '%s\n%s\n\n## UI Requirements\n\n%s\n' "$MB_BEGIN" "$1" "$MB_END" > "$F"; }
mkfacts "$GOOD_FACTS"
check_rc "well formed" 0 mb_design_facts_valid "$F"
mkfacts "$(printf '%s' "$GOOD_FACTS" | sed 's/ adapter=web//')"
check_rc "missing required key" 1 mb_design_facts_valid "$F"
mkfacts "$(printf '%s' "$GOOD_FACTS" | sed 's/--> *$/nonsense=1 -->/')"
check_rc "unknown key" 1 mb_design_facts_valid "$F"
mkfacts "$(printf '%s' "$GOOD_FACTS" | sed 's/adapter=web/adapter=web adapter=tui/')"
check_rc "duplicate key" 1 mb_design_facts_valid "$F"
mkfacts "$(printf '%s' "$GOOD_FACTS" | sed 's/adapter=web/adapter=carrier-pigeon/')"
check_rc "unknown adapter value" 1 mb_design_facts_valid "$F"
mkfacts "$(printf '%s' "$GOOD_FACTS" | sed 's/design_rev=3/design_rev=three/')"
check_rc "non numeric revision" 1 mb_design_facts_valid "$F"
mkfacts "$(printf '%s' "$GOOD_FACTS" | sed 's/design_hash=sha256:a*/design_hash=sha256:xyz/')"
check_rc "malformed hash" 1 mb_design_facts_valid "$F"
mkfacts "$(printf '%s' "$GOOD_FACTS" | sed 's/screens=UI-ORDERS,UI-SHELL/screens=ui-orders/')"
check_rc "screens must be UI-IDs" 1 mb_design_facts_valid "$F"
mkfacts "$(printf '%s' "$GOOD_FACTS" | sed 's/adapter=web/adapter=w*b/')"
check_rc "glob in value refused" 1 mb_design_facts_valid "$F"
# consumes and shared are optional, not unknown.
mkfacts "$(printf '%s' "$GOOD_FACTS" | sed 's/--> *$/consumes=UI-SHELL-NAV shared=UI-SHELL -->/')"
check_rc "optional keys accepted" 0 mb_design_facts_valid "$F"
# A key=value pair broken across lines is illegal; a pair per line is fine.
printf '%s\n<!-- design: manifest=docs/design/manifest.yaml\n     design_rev=3 design_hash=sha256:%s\n     system=docs/design/design-system.md index=docs/design/mockups/index.html\n     adapter=web screens=UI-ORDERS -->\n%s\n' \
	"$MB_BEGIN" "$(printf 'b%.0s' $(seq 64))" "$MB_END" > "$F"
check_rc "wrapped between pairs is fine" 0 mb_design_facts_valid "$F"
# Only the comment BETWEEN the markers counts; a quoted example above it must not.
{
	printf 'Example: <!-- design: adapter=tui -->\n\n'
	printf '%s\n%s\n%s\n' "$MB_BEGIN" "$GOOD_FACTS" "$MB_END"
} > "$F"
check "facts read from inside the block" "web" "$(mb_fact_get "$(mb_design_facts_raw "$F")" adapter)"

echo "== mb_insert_block: placement, replacement, idempotence =="
BLK="$SANDBOX/block.md"
{ printf '%s\n%s\n\n## UI Requirements\n\n| ID |\n|----|\n| UI-ORDERS-TABLE |\n%s\n' "$MB_BEGIN" "$GOOD_FACTS" "$MB_END"; } > "$BLK"

# (a) no markers, no security block -> appended at EOF
printf '# Spec\n\nProse.\n' > "$F"
check_rc "append at EOF" 0 mb_insert_block "$F" "$BLK"
check "block is at the end" "$MB_END" "$(tail -n1 "$F")"
check_rc "second run is a no-op (4)" 4 mb_insert_block "$F" "$BLK"

# (b) security block present -> our block goes ABOVE it, byte-identical after
printf '# Spec\n\nProse.\n\n%s\n<!-- facts: x=1 -->\n\n## Security Requirements\n\n%s\n' \
	"$SEC_BEGIN" "$SEC_END" > "$F"
cp "$F" "$SANDBOX/before.md"
sed -n "/$(printf '%s' "$SEC_BEGIN" | sed 's/[][\/.*^$-]/\\&/g')/,\$p" "$SANDBOX/before.md" > "$SANDBOX/sec-before.txt"
check_rc "insert above security block" 0 mb_insert_block "$F" "$BLK"
sed -n "/$(printf '%s' "$SEC_BEGIN" | sed 's/[][\/.*^$-]/\\&/g')/,\$p" "$F" > "$SANDBOX/sec-after.txt"
check_rc "security block untouched" 0 diff -q "$SANDBOX/sec-before.txt" "$SANDBOX/sec-after.txt"
BL="$(grep -nF -- "$MB_BEGIN" "$F" | head -1 | cut -d: -f1)"
SL="$(grep -nF -- "$SEC_BEGIN" "$F" | head -1 | cut -d: -f1)"
check_rc "design block precedes security block" 0 test "$BL" -lt "$SL"

# (c) existing block -> region replaced, surrounding prose kept
printf '# Spec\n\nBefore.\n\n%s\nold facts\nold table\n%s\n\nAfter.\n' "$MB_BEGIN" "$MB_END" > "$F"
check_rc "replace existing region" 0 mb_insert_block "$F" "$BLK"
check "prose before kept" "1" "$(grep -cF 'Before.' "$F")"
check "prose after kept" "1" "$(grep -cF 'After.' "$F")"
check "old content gone" "0" "$(grep -cF 'old table' "$F")"
check "exactly one begin marker" "1" "$(grep -cF -- "$MB_BEGIN" "$F")"

# (d) damaged block -> refuse and change nothing
printf '# Spec\n\n%s\n%s\n%s\n' "$MB_BEGIN" "$MB_BEGIN" "$MB_END" > "$F"
cp "$F" "$SANDBOX/damaged-before.md"
check_rc "damaged block refused (2)" 2 mb_insert_block "$F" "$BLK"
check_rc "damaged file unchanged" 0 diff -q "$SANDBOX/damaged-before.md" "$F"

# (e) missing target
check_rc "missing file refused (3)" 3 mb_insert_block "$SANDBOX/nope.md" "$BLK"

summary "run-block-tests"
