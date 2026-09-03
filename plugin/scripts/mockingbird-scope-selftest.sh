#!/usr/bin/env bash
# Built-in assertions for mockingbird-scope.sh's deterministic core, without
# any fixture project and without any LLM. Mirrors footgun's score.sh
# --self-test: a fast, always-available correctness signal that never
# depends on the mockingbird-bench fixtures being present.
set -u
# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PLUGIN_ROOT="$(dirname -- "$HERE")"
. "$PLUGIN_ROOT/lib/mockingbird-coveragelib.sh"

fail=0
check() {
	if [ "$2" = "$3" ]; then
		printf 'self-test: PASS  %s\n' "$1"
	else
		printf 'self-test: FAIL  %s (expected [%s], got [%s])\n' "$1" "$2" "$3"
		fail=1
	fi
}

TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
mkdir -p "$TMP/src"
: > "$TMP/src/Real.tsx"

# Rule 1: violated without a terminal link downgrades.
printf 'UI-X | tier=A | render=src/Real.tsx:1 | binding=- | source=- | handler=- | terminal=- | found=x | violated\n' > "$TMP/seam1.txt"
OUT="$(mb_check_seam "$TMP/seam1.txt" "$TMP")"
check "rule1: violated without terminal -> unverified:no-locator" "1" "$(printf '%s\n' "$OUT" | grep -c 'unverified:no-locator$')"

# Rule 2: a file:line pointing outside the root is rejected.
printf 'UI-X | tier=A | render=src/Real.tsx:1 | binding=- | source=- | handler=- | terminal=../etc/passwd:1 | found=x | violated\n' > "$TMP/seam2.txt"
OUT="$(mb_check_seam "$TMP/seam2.txt" "$TMP")"
check "rule2: escaping path rejected" "1" "$(printf '%s\n' "$OUT" | grep -c 'bad file:line')"

# Rule 3: unverified with nothing linked at all collapses to no-locator.
printf 'UI-X | tier=A | render=- | binding=- | source=- | handler=- | terminal=- | found=- | unverified:dynamic\n' > "$TMP/seam3.txt"
OUT="$(mb_check_seam "$TMP/seam3.txt" "$TMP")"
check "rule3: unverified with no links -> no-locator" "1" "$(printf '%s\n' "$OUT" | grep -c 'unverified:no-locator$')"

# Rule 4: tier C can never justify "violated".
printf 'UI-X | tier=C | render=- | binding=- | source=- | handler=- | terminal=src/Real.tsx:1 | found=x | violated\n' > "$TMP/seam4.txt"
OUT="$(mb_check_seam "$TMP/seam4.txt" "$TMP")"
check "rule4: tier C violated downgrades to partial" "1" "$(printf '%s\n' "$OUT" | grep -c 'partial \[Locator schwach\]$')"

# A well-formed, well-linked violated line is left untouched.
printf 'UI-X | tier=A | render=src/Real.tsx:1 | binding=src/Real.tsx:2 | source=src/Real.tsx:3 | handler=src/Real.tsx:4 | terminal=src/Real.tsx:5 | found=group | violated\n' > "$TMP/seam5.txt"
OUT="$(mb_check_seam "$TMP/seam5.txt" "$TMP")"
check "well-formed violated is untouched" "1" "$(printf '%s\n' "$OUT" | grep -c '| violated$')"

# Coverage: an element with no coverage line at all is never a silent pass.
cat > "$TMP/manifest.yaml" <<'YAML'
schema: mockingbird/1
project: selftest
revision: 1
updated: 2026-01-01
design_system: docs/design/design-system.md
mockups_index: docs/design/mockups/index.html
tokens_css: docs/design/mockups/tokens.css
primary_adapter: web
screens:
  - id: UI-S
    kind: page
    title: S
    artboard: docs/design/mockups/s.html
    elements:
      - id: UI-S-A
        type: text
        label: A
        status: required
        verify: required
        data_source: static
        states:
          - { id: default }
YAML
: > "$TMP/coverage-empty.txt"
mb_manifest_coverage "$TMP/coverage-empty.txt" "$TMP/manifest.yaml" "$TMP" > "$TMP/report.txt"
RC=$?
check "no coverage line at all -> MISMATCH (rc=1)" "1" "$RC"
check "no coverage line at all -> reported as blocker" "1" "$(grep -c 'kein Coverage-Eintrag' "$TMP/report.txt")"

printf 'UI-S-A | structure | ok | src/Real.tsx:1\n' > "$TMP/coverage-ok.txt"
mb_manifest_coverage "$TMP/coverage-ok.txt" "$TMP/manifest.yaml" "$TMP" > "$TMP/report2.txt"
check "fully covered, all ok -> MATCH (rc=0)" "0" "$?"
check "MATCH verdict line present" "1" "$(grep -c '^VERDICT: MATCH$' "$TMP/report2.txt")"

if [ "$fail" -eq 0 ]; then
	echo "self-test: PASS (all checks)"
	exit 0
else
	echo "self-test: FAIL"
	exit 1
fi
