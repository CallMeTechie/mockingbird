#!/usr/bin/env bash
# mb-design-check.sh: the deterministic half of /design-check -- manifest
# validity, block freshness, the split invariants, per-task Design: lines.
set -u
# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(dirname -- "$HERE")"
. "$HERE/_helper.sh"
CHECK="$ROOT/plugin/scripts/mb-design-check.sh"
INSERT="$ROOT/plugin/scripts/mb-insert-block.sh"

sandbox
P="$SANDBOX/proj"
mkdir -p "$P/docs/design/mockups" "$P/docs/superpowers/specs" "$P/docs/superpowers/plans"
cp "$ROOT/tests/fixtures/manifest/valid.yaml" "$P/docs/design/manifest.yaml"
printf '# ds\n' > "$P/docs/design/design-system.md"
: > "$P/docs/design/mockups/index.html"; : > "$P/docs/design/mockups/tokens.css"
: > "$P/docs/design/mockups/ui-orders.html"; : > "$P/docs/design/mockups/ui-shell.html"
SPEC="$P/docs/superpowers/specs/2026-09-03-orders-design.md"   # matches the fixture's allocations: entry
printf '# Orders\n\nProse.\n' > "$SPEC"

check_rc "no manifest -> 3" 3 "$CHECK" "$SANDBOX/nowhere"

echo "== clean project =="
"$INSERT" "$SPEC" --root "$P" --spec docs/superpowers/specs/2026-09-03-orders-design.md >/dev/null
cp "$ROOT/tests/fixtures/plans/orders-plan.md" "$P/docs/superpowers/plans/2026-09-03-orders.md"
OUT="$("$CHECK" "$P")"; RC=$?
check "clean project -> exit 0" "0" "$RC"
check "clean project -> 0 Befunde" "VERDICT: 0 Befund(e)" "$(printf '%s\n' "$OUT" | tail -n1)"

echo "== stale block =="
printf '<html>v2</html>\n' > "$P/docs/design/mockups/ui-orders.html"
OUT="$("$CHECK" "$P")"; RC=$?
check "stale block -> exit 1" "1" "$RC"
check "stale block named" "1" "$(printf '%s\n' "$OUT" | grep -c 'Design-Block veraltet')"
"$INSERT" "$SPEC" --root "$P" --spec docs/superpowers/specs/2026-09-03-orders-design.md >/dev/null

echo "== split invariants =="
python3 - "$P/docs/design/manifest.yaml" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read()
s = s.replace("    owns: [UI-ORDERS, UI-SHELL]", "    owns: [UI-ORDERS]")
open(p,"w").write(s)
PY
"$INSERT" "$SPEC" --root "$P" --spec docs/superpowers/specs/2026-09-03-orders-design.md >/dev/null
OUT="$("$CHECK" "$P")"
check "screen without owner is reported" "1" "$(printf '%s\n' "$OUT" | grep -c 'UI-SHELL in keiner allocations-Zeile')"
python3 - "$P/docs/design/manifest.yaml" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read()
s = s.replace("    owns: [UI-ORDERS]\n    consumes: []", "    owns: [UI-ORDERS]\n    consumes: []\n  - spec: docs/superpowers/specs/2026-09-04-shell-design.md\n    owns: [UI-SHELL, UI-ORDERS]\n    consumes: []")
open(p,"w").write(s)
PY
OUT="$("$CHECK" "$P")"
check "double owner is reported" "1" "$(printf '%s\n' "$OUT" | grep -c 'UI-ORDERS hat mehr als einen Owner')"
check "missing allocated spec is reported" "1" "$(printf '%s\n' "$OUT" | grep -c 'Zugeordnete Spec existiert nicht')"

echo "== plan without Design: lines =="
cp "$ROOT/tests/fixtures/manifest/valid.yaml" "$P/docs/design/manifest.yaml"
"$INSERT" "$SPEC" --root "$P" --spec docs/superpowers/specs/2026-09-03-orders-design.md >/dev/null
sed -i 's/^\*\*Design:\*\* kein UI-Anteil\.$//' "$P/docs/superpowers/plans/2026-09-03-orders.md"
OUT="$("$CHECK" "$P")"; RC=$?
check "two tasks lost their Design: line -> two findings" "2" "$(printf '%s\n' "$OUT" | grep -c 'Task ohne \*\*Design:\*\*-Zeile')"
check "exit 1" "1" "$RC"
printf '# Plan\n\n### Task 1: x\n\nsteps\n' > "$P/docs/superpowers/plans/2026-09-03-other.md"
OUT="$("$CHECK" "$P")"
check "plan not naming the manifest is reported" "1" "$(printf '%s\n' "$OUT" | grep -c 'nennt docs/design/manifest.yaml nicht')"

summary "run-design-check-tests"
