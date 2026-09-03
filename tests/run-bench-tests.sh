#!/usr/bin/env bash
# Tests the bench SCORER (tests/bench/score.sh) and the bench fixtures'
# structural soundness. Never invokes an LLM — /mockingbird-bench itself is
# LLM-driven and therefore non-deterministic, same caveat footgun states for
# /footgun-bench; what's tested here is everything around it that isn't.
set -u
# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(dirname -- "$HERE")"
. "$HERE/_helper.sh"

SCORE="$ROOT/tests/bench/score.sh"
SCOPE="$ROOT/plugin/scripts/mockingbird-scope.sh"

echo "== score.sh self-test (locale-independent arithmetic, no fixtures) =="
check_rc "score.sh --self-test passes" 0 "$SCORE" --self-test
LC_ALL=de_DE.UTF-8 check_rc "self-test still passes under a comma-decimal locale" 0 "$SCORE" --self-test

echo "== usage errors =="
check_rc "no args -> usage" 2 "$SCORE"
check_rc "--mode without a submode -> usage" 2 "$SCORE" --mode
check_rc "recall with one arg -> usage" 2 "$SCORE" --mode recall "$ROOT/tests/bench/expected/mismatch.expected.json"
check_rc "missing findings file -> usage" 2 "$SCORE" --mode recall "/nonexistent/findings.json" "$ROOT/tests/bench/expected/clean.expected.json"

echo "== bench fixtures: both validate against the deterministic core =="
check_rc "app-mismatch manifest validates" 0 "$SCOPE" --validate --root "$ROOT/tests/fixtures/bench/app-mismatch"
check_rc "app-clean manifest validates" 0 "$SCOPE" --validate --root "$ROOT/tests/fixtures/bench/app-clean"
check "both fixtures share the same 6-element manifest" "6" "$("$SCOPE" --elements --root "$ROOT/tests/fixtures/bench/app-mismatch" | wc -l | tr -d ' ')"
check "app-clean has the identical element set" "6" "$("$SCOPE" --elements --root "$ROOT/tests/fixtures/bench/app-clean" | wc -l | tr -d ' ')"

echo "== golden files are well-formed and cover every planted deviation class =="
check_rc "mismatch golden is valid JSON" 0 jq -e . "$ROOT/tests/bench/expected/mismatch.expected.json"
check_rc "clean golden is valid JSON" 0 jq -e . "$ROOT/tests/bench/expected/clean.expected.json"
check "clean golden is empty (nothing should be flagged)" "[]" "$(jq -c . "$ROOT/tests/bench/expected/clean.expected.json")"
for cls in violated partial ok "unverified:external-boundary"; do
	check "mismatch golden includes class '$cls'" "true" "$(jq --arg c "$cls" '[.[] | select(.class == $c)] | length > 0' "$ROOT/tests/bench/expected/mismatch.expected.json")"
done
check "every golden element id follows the manifest ID grammar" "0" "$(jq -r '.[].element' "$ROOT/tests/bench/expected/mismatch.expected.json" | grep -cvE '^UI-[A-Z0-9]+(-[A-Z0-9]+){0,3}$')"
check "every golden element exists in the fixture manifest" "0" "$(comm -23 <(jq -r '.[].element' "$ROOT/tests/bench/expected/mismatch.expected.json" | sort -u) <("$SCOPE" --elements --root "$ROOT/tests/fixtures/bench/app-mismatch" | cut -f4 | sort -u) | wc -l | tr -d ' ')"

echo "== decoys are locatable (a bench that can't even find the decoy proves nothing) =="
check_rc "decoy 1 (correctly-filtered cost center) is locatable" 0 "$SCOPE" --locate UI-EMP-COSTCENTER --root "$ROOT/tests/fixtures/bench/app-mismatch"
check_rc "decoy 2 (external boundary) is locatable" 0 "$SCOPE" --locate UI-EMP-NAME --root "$ROOT/tests/fixtures/bench/app-mismatch"

summary "run-bench-tests"
