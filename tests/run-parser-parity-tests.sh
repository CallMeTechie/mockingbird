#!/usr/bin/env bash
# The two manifest parsers must answer identically.
#
# mockingbird reads a manifest through yq+jq when both are installed and through a line-based
# awk parser when they are not. Every other suite exercises whichever path the machine running
# it happens to have -- and that is how the yq path went unchecked for its whole life: this
# container has no yq, so the suite was green here and red on a CI runner, which ships one.
#
# The bug that hid there was not subtle once seen: mb_manifest_meta handed a jq expression
# straight to yq, which cannot parse jq syntax. yq failed, 2>/dev/null swallowed the message,
# `return $?` reported success, and every scalar in a rendered spec block came out empty. The
# fallback was never reached, because the yq branch had already returned.
#
# So this suite compares the two, function by function, on the same input. It skips when only
# one path is available -- with a loud line, because a skip here means the guarantee is not
# being checked on this machine.
set -u
# shellcheck disable=SC1007
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(dirname -- "$HERE")"
. "$HERE/_helper.sh"

LIB="$ROOT/plugin/lib/mockingbird-manifestlib.sh"

if ! command -v yq >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    echo "run-parser-parity-tests: SKIPPED -- needs both yq and jq to compare the two paths"
    echo "  (install yq to check the branch CI runners take)"
    summary "run-parser-parity-tests"
    exit 0
fi

# Runs one library function under a PATH that hides yq, so the awk fallback is taken.
# Hiding yq rather than adding a test-only switch to the library keeps the production code
# free of anything that exists solely for tests.
without_yq() {
    local fn="$1" file="$2"
    env -i PATH="/usr/bin:/bin" HOME="$HOME" bash -c '
        . "$1" 2>/dev/null
        command -v yq >/dev/null 2>&1 && { echo "yq still reachable" >&2; exit 99; }
        "$2" "$3"
    ' _ "$LIB" "$fn" "$file"
}

with_yq() {
    local fn="$1" file="$2"
    bash -c '. "$1"; "$2" "$3"' _ "$LIB" "$fn" "$file"
}

compare() {
    local label="$1" fn="$2" file="$3"
    local a b
    a="$(with_yq "$fn" "$file")"
    b="$(without_yq "$fn" "$file")"
    check "$label" "$b" "$a"
}

FIXTURES=("$ROOT/tests/fixtures/manifest/valid.yaml")
for fixture in "${FIXTURES[@]}"; do
    name="$(basename "$fixture")"
    echo "== $name: the two parsers agree =="
    compare "$name: element TSV" mb_manifest_to_tsv "$fixture"
    compare "$name: metadata" mb_manifest_meta "$fixture"
    compare "$name: allocations" mb_manifest_allocations "$fixture"
done

# The one that started this: every declared scalar has to come back non-empty on both paths.
# An empty value is what a failing yq produced, and nothing downstream could tell it from a
# manifest that genuinely omits the key.
echo "== no scalar comes back empty =="
META="$(with_yq mb_manifest_meta "$ROOT/tests/fixtures/manifest/valid.yaml")"
for key in schema project revision design_system mockups_index tokens_css primary_adapter; do
    value="$(printf '%s\n' "$META" | awk -F'\t' -v k="$key" '$1==k{print $2}')"
    check "$key is present and non-empty" "yes" "$([ -n "$value" ] && echo yes || echo no)"
done

# A file yq refuses must be a parse error, not an empty read. In a pipe the exit status is
# jq's, and jq succeeds on empty input -- so a broken manifest used to come back as "valid,
# no elements" and failed its semantic checks instead, which named the wrong problem.
echo "== a broken manifest is a parse error on both paths =="
sandbox
BROKEN="$SANDBOX/broken.yaml"
printf 'schema: mockingbird/1\nscreens:\n  - id: UI-X\n    elements:\n      - id: UI-X-A\n        type: text\n   this line has odd indent\n' > "$BROKEN"
bash -c '. "$1"; mb_manifest_to_tsv "$2" >/dev/null' _ "$LIB" "$BROKEN"
check "with yq: exit 5" "5" "$?"
without_yq mb_manifest_to_tsv "$BROKEN" >/dev/null
check "without yq: exit 5" "5" "$?"

# Block scalars are the other place the two disagreed: yq preserves the newlines a > or |
# scalar carries, and @tsv escapes them into a literal \n. The TSV is one record per line by
# construction, so both paths have to fold.
echo "== block scalars are folded on both paths =="
FOLDED="$SANDBOX/folded.yaml"
cat > "$FOLDED" <<'YAML'
schema: mockingbird/1
project: p
revision: 1
screens:
  - id: UI-X
    kind: page
    title: X
    artboard: docs/design/mockups/x.html
    elements:
      - id: UI-X-A
        type: text
        label: >
          a label written
          across two lines
        status: required
        verify: required
        data_source: static
        semantic_anchor:
          means: |
            first line
            second line
          concept: thing
        states:
          - { id: default }
YAML
for path in with without; do
    if [ "$path" = "with" ]; then out="$(with_yq mb_manifest_to_tsv "$FOLDED")"; else out="$(without_yq mb_manifest_to_tsv "$FOLDED")"; fi
    check "$path yq: no literal backslash-n in the TSV" "0" "$(printf '%s' "$out" | grep -c '\\n')"
    check "$path yq: label is one folded line" "a label written across two lines" "$(printf '%s' "$out" | cut -f6)"
done

summary "run-parser-parity-tests"
