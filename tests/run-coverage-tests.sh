#!/usr/bin/env bash
# Every seam anti-hallucination rule and every coverage verdict rule, each as
# its own case. plugin/scripts/mockingbird-scope-selftest.sh covers the same
# ground more tersely (footgun-style self-test, no fixtures); this suite is
# the exhaustive version with the full _helper.sh check/check_rc machinery.
set -u
# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(dirname -- "$HERE")"
. "$HERE/_helper.sh"
. "$ROOT/plugin/lib/mockingbird-coveragelib.sh"

sandbox
mkdir -p "$SANDBOX/src"
: > "$SANDBOX/src/Real.tsx"

seam_line() { printf 'UI-X | tier=%s | render=%s | binding=%s | source=%s | handler=%s | terminal=%s | found=%s | %s\n' \
	"$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8"; }

echo "== mb_check_seam: rule 1 — violated needs an existing terminal link =="
seam_line A src/Real.tsx:1 - - - - x violated > "$SANDBOX/s.txt"
OUT="$(mb_check_seam "$SANDBOX/s.txt" "$SANDBOX")"
check "no terminal at all -> no-locator" "unverified:no-locator" "${OUT##*| }"
seam_line A src/Real.tsx:1 - - - src/nope.tsx:9 x violated > "$SANDBOX/s.txt"
OUT="$(mb_check_seam "$SANDBOX/s.txt" "$SANDBOX")"
check "terminal points at a missing file -> no-locator (rule 2 subsumes)" "unverified:no-locator [bad file:line]" "${OUT##*| }"
seam_line A src/Real.tsx:1 - - - src/Real.tsx:1 x violated > "$SANDBOX/s.txt"
OUT="$(mb_check_seam "$SANDBOX/s.txt" "$SANDBOX")"
check "existing terminal -> violated survives" "violated" "${OUT##*| }"

echo "== mb_check_seam: rule 2 — every linked file must exist under root =="
seam_line A src/Real.tsx:1 - - - src/Real.tsx:1 x violated > "$SANDBOX/s.txt"
check "sound links pass through" "0" "$(mb_check_seam "$SANDBOX/s.txt" "$SANDBOX" | grep -c 'bad file:line')"
seam_line A /etc/passwd:1 - - - src/Real.tsx:1 x violated > "$SANDBOX/s.txt"
check "absolute path is rejected" "1" "$(mb_check_seam "$SANDBOX/s.txt" "$SANDBOX" | grep -c 'bad file:line')"
seam_line A node_modules/x/y.tsx:1 - - - src/Real.tsx:1 x violated > "$SANDBOX/s.txt"
check "node_modules path is rejected" "1" "$(mb_check_seam "$SANDBOX/s.txt" "$SANDBOX" | grep -c 'bad file:line')"
seam_line A ../outside.tsx:1 - - - src/Real.tsx:1 x violated > "$SANDBOX/s.txt"
check "path escaping the root is rejected" "1" "$(mb_check_seam "$SANDBOX/s.txt" "$SANDBOX" | grep -c 'bad file:line')"

echo "== mb_check_seam: rule 3 — unverified with nothing linked collapses =="
seam_line A - - - - - - unverified:dynamic > "$SANDBOX/s.txt"
OUT="$(mb_check_seam "$SANDBOX/s.txt" "$SANDBOX")"
check "no links at all -> forced to no-locator" "unverified:no-locator" "${OUT##*| }"
seam_line A src/Real.tsx:1 - - - - - unverified:dynamic > "$SANDBOX/s.txt"
OUT="$(mb_check_seam "$SANDBOX/s.txt" "$SANDBOX")"
check "at least one link -> the original reason is kept" "unverified:dynamic" "${OUT##*| }"

echo "== mb_check_seam: rule 4 — tier C can never justify violated =="
seam_line C - - - - src/Real.tsx:1 x violated > "$SANDBOX/s.txt"
check "tier C violated is downgraded" "1" "$(mb_check_seam "$SANDBOX/s.txt" "$SANDBOX" | grep -c 'partial \[Locator schwach\]$')"
seam_line A - - - - src/Real.tsx:1 x violated > "$SANDBOX/s.txt"
check "tier A violated is not touched by rule 4" "1" "$(mb_check_seam "$SANDBOX/s.txt" "$SANDBOX" | grep -c '| violated$')"
seam_line C - - - - src/Real.tsx:1 x ok > "$SANDBOX/s.txt"
check "tier C 'ok' is untouched (rule 4 only fires on violated)" "1" "$(mb_check_seam "$SANDBOX/s.txt" "$SANDBOX" | grep -c '| ok$')"

echo "== mb_check_seam: malformed input is flagged, never silently dropped =="
printf 'this is not a seam line at all\n' > "$SANDBOX/s.txt"
check "malformed line is marked, not dropped" "1" "$(mb_check_seam "$SANDBOX/s.txt" "$SANDBOX" | grep -c '^MALFORMED:')"

echo "== mb_check_seam: missing file =="
check_rc "missing seam file -> 3" 3 mb_check_seam "$SANDBOX/nope.txt" "$SANDBOX"

echo "== mb_manifest_coverage: fixture manifest, one rule per case =="
MAN="$ROOT/tests/fixtures/manifest/valid.yaml"
# valid.yaml elements: UI-ORDERS-TABLE(required), UI-ORDERS-EMPTY(required),
# UI-ORDERS-EXPORT(status=deferred, verify=skip+reason), UI-SHELL-NAV(required)

cov_all_ok() {
	cat <<'COV'
UI-ORDERS-TABLE | structure | ok | -
UI-ORDERS-EMPTY | structure | ok | -
UI-SHELL-NAV | structure | ok | -
COV
}

echo "-- rule 6: element with no coverage line at all --"
cov_all_ok | grep -v UI-SHELL-NAV > "$SANDBOX/cov.txt"
mb_manifest_coverage "$SANDBOX/cov.txt" "$MAN" "$SANDBOX" > "$SANDBOX/rep.txt"
check "missing required element -> MISMATCH exit" "1" "$?"
check "named as a blocker" "1" "$(grep -c 'UI-SHELL-NAV (kein Coverage-Eintrag)' "$SANDBOX/rep.txt")"

echo "-- rule 1/2: required + blocking stage on violated/partial/unverified:no-locator --"
cov_all_ok > "$SANDBOX/cov.txt"
sed -i 's/UI-ORDERS-TABLE | structure | ok | -/UI-ORDERS-TABLE | semantic | violated | src\/x.tsx:1/' "$SANDBOX/cov.txt"
mb_manifest_coverage "$SANDBOX/cov.txt" "$MAN" "$SANDBOX" > "$SANDBOX/rep.txt"; RC=$?
check "required+violated -> MISMATCH" "1" "$RC"
check "blocker names the element" "1" "$(grep -cx 'UI-ORDERS-TABLE' "$SANDBOX/rep.txt")"

cov_all_ok > "$SANDBOX/cov.txt"
sed -i 's/UI-ORDERS-TABLE | structure | ok | -/UI-ORDERS-TABLE | semantic | partial | src\/x.tsx:1/' "$SANDBOX/cov.txt"
mb_manifest_coverage "$SANDBOX/cov.txt" "$MAN" "$SANDBOX" > /dev/null; RC=$?
check "required+partial -> MISMATCH" "1" "$RC"

cov_all_ok > "$SANDBOX/cov.txt"
sed -i 's/UI-ORDERS-TABLE | structure | ok | -/UI-ORDERS-TABLE | semantic | unverified:no-locator | -/' "$SANDBOX/cov.txt"
mb_manifest_coverage "$SANDBOX/cov.txt" "$MAN" "$SANDBOX" > /dev/null; RC=$?
check "required+unverified:no-locator -> MISMATCH" "1" "$RC"

echo "-- rule 3: external-boundary/dynamic/out-of-scope never affect the verdict --"
cov_all_ok > "$SANDBOX/cov.txt"
sed -i 's/UI-ORDERS-TABLE | structure | ok | -/UI-ORDERS-TABLE | semantic | unverified:external-boundary | -/' "$SANDBOX/cov.txt"
mb_manifest_coverage "$SANDBOX/cov.txt" "$MAN" "$SANDBOX" > "$SANDBOX/rep.txt"; RC=$?
check "external-boundary -> still MATCH" "0" "$RC"
check "listed as an open gap" "1" "$(grep -c 'UI-ORDERS-TABLE (semantic): unverified:external-boundary' "$SANDBOX/rep.txt")"

echo "-- rule 4: recommended + violated -> Important, verdict untouched --"
sed 's/verify: required/verify: recommended/' "$MAN" > "$SANDBOX/rec.yaml"
cov_all_ok > "$SANDBOX/cov.txt"
sed -i 's/UI-ORDERS-TABLE | structure | ok | -/UI-ORDERS-TABLE | semantic | violated | src\/x.tsx:1/' "$SANDBOX/cov.txt"
mb_manifest_coverage "$SANDBOX/cov.txt" "$SANDBOX/rec.yaml" "$SANDBOX" > "$SANDBOX/rep.txt"; RC=$?
check "recommended+violated -> not a MISMATCH" "0" "$RC"
check "still reported as Important" "1" "$(grep -c 'UI-ORDERS-TABLE: recommended, abweichend' "$SANDBOX/rep.txt")"
check "verdict is MATCH WITH NOTES" "1" "$(grep -c '^VERDICT: MATCH WITH NOTES$' "$SANDBOX/rep.txt")"

echo "-- rule 5: states/tokens stages never affect the verdict --"
cov_all_ok > "$SANDBOX/cov.txt"
printf 'UI-ORDERS-TABLE | states | violated | -\nUI-ORDERS-TABLE | tokens | violated | -\n' >> "$SANDBOX/cov.txt"
mb_manifest_coverage "$SANDBOX/cov.txt" "$MAN" "$SANDBOX" > "$SANDBOX/rep.txt"; RC=$?
check "states/tokens violations -> still MATCH" "0" "$RC"

echo "-- rule 7: verify:skip with a reason is excluded; without a reason it is required --"
cov_all_ok > "$SANDBOX/cov.txt"   # note: no UI-ORDERS-EXPORT line at all
mb_manifest_coverage "$SANDBOX/cov.txt" "$MAN" "$SANDBOX" > "$SANDBOX/rep.txt"; RC=$?
check "skip-with-reason is excluded, not a blocker" "0" "$(grep -c 'UI-ORDERS-EXPORT' "$SANDBOX/rep.txt")"
check "verdict unaffected by the excluded element" "0" "$RC"

sed '/^        reason:/d' "$MAN" > "$SANDBOX/noreason.yaml"
mb_manifest_coverage "$SANDBOX/cov.txt" "$SANDBOX/noreason.yaml" "$SANDBOX" > "$SANDBOX/rep.txt"; RC=$?
check "skip WITHOUT a reason is treated as required" "1" "$RC"
check "named as a blocker" "1" "$(grep -c 'UI-ORDERS-EXPORT (kein Coverage-Eintrag)' "$SANDBOX/rep.txt")"

echo "-- annotated classes from mb_check_seam are recognized --"
cov_all_ok > "$SANDBOX/cov.txt"
sed -i 's/UI-ORDERS-TABLE | structure | ok | -/UI-ORDERS-TABLE | semantic | partial [Locator schwach] | src\/x.tsx:1/' "$SANDBOX/cov.txt"
mb_manifest_coverage "$SANDBOX/cov.txt" "$MAN" "$SANDBOX" > /dev/null; RC=$?
check "'partial [Locator schwach]' still counts as partial -> MISMATCH" "1" "$RC"

echo "== mb_seam_to_coverage: the bridge =="
seam_line A src/Real.tsx:1 - - - src/Real.tsx:5 group violated > "$SANDBOX/s.txt"
check "violated -> coverage line with terminal as loc" "UI-X | semantic | violated | src/Real.tsx:5" "$(mb_seam_to_coverage "$SANDBOX/s.txt" semantic)"
seam_line C src/Real.tsx:1 - - - src/Real.tsx:5 group violated > "$SANDBOX/s.txt"
mb_check_seam "$SANDBOX/s.txt" "$SANDBOX" > "$SANDBOX/s2.txt"
check "annotation stripped, base class kept" "UI-X | flow | partial | src/Real.tsx:5" "$(mb_seam_to_coverage "$SANDBOX/s2.txt" flow)"
seam_line A src/Real.tsx:1 - - - - - unverified:dynamic > "$SANDBOX/s.txt"
check "no terminal -> render used as loc" "UI-X | semantic | unverified:dynamic | src/Real.tsx:1" "$(mb_seam_to_coverage "$SANDBOX/s.txt" semantic)"
printf 'MB-SEAM\nMALFORMED: junk\nEND\n' > "$SANDBOX/s.txt"
check "MALFORMED passes through, markers dropped" "MALFORMED: junk" "$(mb_seam_to_coverage "$SANDBOX/s.txt" semantic)"
check_rc "unknown stage -> 2" 2 mb_seam_to_coverage "$SANDBOX/s.txt" tokens
check_rc "missing file -> 3" 3 mb_seam_to_coverage "$SANDBOX/nope" semantic

echo "-- fully clean run --"
cov_all_ok > "$SANDBOX/cov.txt"
mb_manifest_coverage "$SANDBOX/cov.txt" "$MAN" "$SANDBOX" > "$SANDBOX/rep.txt"; RC=$?
check "all required elements ok, skip excluded -> MATCH" "0" "$RC"
check "MATCH verdict line" "1" "$(grep -c '^VERDICT: MATCH$' "$SANDBOX/rep.txt")"

check_rc "missing coverage file -> 3" 3 mb_manifest_coverage "$SANDBOX/nope.txt" "$MAN" "$SANDBOX"
check_rc "missing manifest -> propagates 3" 3 mb_manifest_coverage "$SANDBOX/cov.txt" "$SANDBOX/nope.yaml" "$SANDBOX"

summary "run-coverage-tests"
