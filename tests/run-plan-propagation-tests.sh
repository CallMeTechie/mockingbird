#!/usr/bin/env bash
# The single most important test in this plugin: does a per-task design table
# actually survive the real subagent-driven-development task-brief cut?
#
# Runs the VENDORED, verbatim superpowers 6.3.0 task-brief awk program (see
# tests/vendor/README.md) against a fixture plan authored exactly the way the
# carrying-design-through skill is instructed to write one — plan header
# (Channel A), Global Constraints (Channel B), and a per-task Design table
# (Channel C). A reimplementation of the cut logic could silently drift from
# upstream and give a false sense of safety; this test never reimplements it.
set -u
# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(dirname -- "$HERE")"
. "$HERE/_helper.sh"

PLAN="$ROOT/tests/fixtures/plans/orders-plan.md"
VENDOR_AWK="$ROOT/tests/vendor/superpowers-6.3.0-task-brief.awk"
[ -f "$VENDOR_AWK" ] || { echo "vendored task-brief awk missing" >&2; exit 1; }

sandbox

# Reproduces the real invocation from superpowers' scripts/task-brief:
#   awk -v n="$n" '...' "$plan" > "$out"
# by eval-ing the vendored line with plan/n/out in scope -- not a paraphrase.
# shellcheck disable=SC2034  # plan/n/out are used inside the eval'd vendor snippet
task_brief() {
	local plan="$1" n="$2" out="$3"
	# shellcheck disable=SC1090
	eval "$(cat "$VENDOR_AWK")"
}

task_brief "$PLAN" 1 "$SANDBOX/brief-1.md"
task_brief "$PLAN" 2 "$SANDBOX/brief-2.md"
task_brief "$PLAN" 3 "$SANDBOX/brief-3.md"

echo "== Channel A (plan header) never reaches any brief =="
for n in 1 2 3; do
	check "no **Spec:** in brief $n" "0" "$(grep -cF '**Spec:**' "$SANDBOX/brief-$n.md")"
	check "no **Design:** header line in brief $n" "0" "$(grep -c '^\*\*Design:\*\* \`docs/design/manifest.yaml\`' "$SANDBOX/brief-$n.md")"
	check "no Design Scope line in brief $n" "0" "$(grep -cF '**Design Scope:**' "$SANDBOX/brief-$n.md")"
done

echo "== Channel B (Global Constraints) never reaches any brief =="
for n in 1 2 3; do
	check "no Global Constraints heading in brief $n" "0" "$(grep -cF '## Global Constraints' "$SANDBOX/brief-$n.md")"
	check "no data-ui-id constraint line in brief $n" "0" "$(grep -cF 'Jedes gebaute UI-Element trägt seine Manifest-ID' "$SANDBOX/brief-$n.md")"
done

echo "== Channel C (per-task Design table) reaches exactly its own brief =="
check_rc "task 1 brief non-empty" 0 test -s "$SANDBOX/brief-1.md"
check "task 1 has no UI design table" "0" "$(grep -cF 'UI-ORDERS-TABLE' "$SANDBOX/brief-1.md")"
check "task 1 states no UI part" "1" "$(grep -c '^\*\*Design:\*\* kein UI-Anteil\.$' "$SANDBOX/brief-1.md")"

check_rc "task 2 brief non-empty" 0 test -s "$SANDBOX/brief-2.md"
check "task 2 carries the design table header" "1" "$(grep -cF '| ID | Element | Fachlicher Anker | Zustände | Copy |' "$SANDBOX/brief-2.md")"
check "task 2 carries the exact UI-ORDERS-TABLE row" "1" "$(grep -cF 'UI-ORDERS-TABLE | Tabelle offener Bestellungen' "$SANDBOX/brief-2.md")"
check "task 2 carries the exact UI-ORDERS-EMPTY row" "1" "$(grep -cF 'UI-ORDERS-EMPTY | Leerzustand der Bestellliste' "$SANDBOX/brief-2.md")"
check "task 2 carries the not: clause verbatim" "1" "$(grep -cF 'Nicht: invoice, shipment.' "$SANDBOX/brief-2.md")"
check "task 2 carries the locator instruction" "1" "$(grep -cF 'data-ui-id=' "$SANDBOX/brief-2.md")"
check "task 2 does not leak task 1's interface" "0" "$(grep -cF 'GET /api/v1/orders?status=open -> { orders: Order[] }\` from Task 1' "$SANDBOX/brief-2.md")"

echo "== Channel C isolation: task 1's brief is untouched by task 2's table =="
check "task 1 carries only its own interface" "1" "$(grep -c 'Produces:' "$SANDBOX/brief-1.md")"

echo "== fence handling: a Task-shaped heading inside a fence is not a task boundary =="
check_rc "task 3 brief non-empty" 0 test -s "$SANDBOX/brief-3.md"
check "task 3 states no UI part" "1" "$(grep -c '^\*\*Design:\*\* kein UI-Anteil\.$' "$SANDBOX/brief-3.md")"
check "brief 3 contains its own real content, not just the fence" "1" "$(grep -cF 'src/components/ExportButton.tsx' "$SANDBOX/brief-3.md")"
# A fence only protects task BOUNDARY detection ("is this a new ### Task N
# heading"), it does not hide the fenced text from a task that is already
# active -- once inside task 3, task 3's own fenced example is legitimately
# part of task 3's content and is printed verbatim. What must never happen is
# that fenced content bleeds into a DIFFERENT task's brief, or that the
# heading-shaped line inside the fence is mistaken for a real task boundary.
check "fenced example is task 3's own content, not task 1's" "0" "$(grep -cF 'UI-FAKE-ID' "$SANDBOX/brief-1.md")"
check "fenced example is task 3's own content, not task 2's" "0" "$(grep -cF 'UI-FAKE-ID' "$SANDBOX/brief-2.md")"
check "fenced example appears once in task 3's own brief" "1" "$(grep -cF 'UI-FAKE-ID' "$SANDBOX/brief-3.md")"
# The fake "### Task 99" heading lives inside the fence and must not have
# been treated as a real task boundary: task 3's own trailing steps (after
# the fence closes) must still be present in its brief.
check "task 3's own steps survive past the fence" "1" "$(grep -c '\*\*Step 5: Commit\*\*' "$SANDBOX/brief-3.md")"

# There is no Task 4 in the fixture plan. The awk fragment alone (not the
# wrapping task-brief script, which is not vendored) has no "not found"
# signal beyond an empty result -- that emptiness is the contract this test
# checks; task-brief itself turns it into exit 3 (see its own source).
task_brief "$PLAN" 4 "$SANDBOX/brief-4.md"
check_rc "nonexistent task yields an empty file" 0 test ! -s "$SANDBOX/brief-4.md"

echo "== byte-for-byte: task 2's design table survives verbatim, not paraphrased =="
diff <(sed -n '/^| ID | Element/,/^| UI-ORDERS-EMPTY/p' "$PLAN") \
     <(sed -n '/^| ID | Element/,/^| UI-ORDERS-EMPTY/p' "$SANDBOX/brief-2.md") \
     > "$SANDBOX/table.diff" 2>&1
check_rc "design table is byte-identical in plan vs brief" 0 test ! -s "$SANDBOX/table.diff"

summary "run-plan-propagation-tests"
