#!/usr/bin/env bash
# mockingbird-scope.sh: the CLI wiring around manifestlib/coveragelib/adapters
# --validate/--elements/--locate/--scope/--tokens/--fix-scope/--check-seam/
# --coverage all dispatch correctly and pass through the right exit codes.
# Rule-level correctness is tested in run-manifest-tests.sh, run-coverage-
# tests.sh and run-adapter-tests.sh; this suite is about the wiring.
set -u
# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(dirname -- "$HERE")"
. "$HERE/_helper.sh"
. "$ROOT/plugin/lib/mockingbird-manifestlib.sh"

SCOPE="$ROOT/plugin/scripts/mockingbird-scope.sh"

sandbox
PROJ="$SANDBOX/proj"
mkdir -p "$PROJ/docs/design/mockups" "$PROJ/src"
git init -q "$PROJ"
cp "$ROOT/tests/fixtures/manifest/valid.yaml" "$PROJ/docs/design/manifest.yaml"
printf '# ds\n' > "$PROJ/docs/design/design-system.md"
: > "$PROJ/docs/design/mockups/index.html"
printf ':root{--x:1}\n' > "$PROJ/docs/design/mockups/tokens.css"
: > "$PROJ/docs/design/mockups/ui-orders.html"
: > "$PROJ/docs/design/mockups/ui-shell.html"

echo "== usage / dispatch =="
check_rc "no args -> usage (2)" 2 "$SCOPE"
check_rc "unknown mode -> usage (2)" 2 "$SCOPE" --bogus --root "$PROJ"
check_rc "--locate without an id -> usage (2)" 2 "$SCOPE" --locate --root "$PROJ"

echo "== --validate =="
check_rc "valid manifest -> 0" 0 "$SCOPE" --validate --root "$PROJ"
check "prints 'valid'" "valid" "$("$SCOPE" --validate --root "$PROJ")"
check_rc "missing manifest -> 3" 3 "$SCOPE" --validate --root "$SANDBOX/nowhere"
sed 's/UI-ORDERS-EMPTY/UI-ORDERS-TABLE/' "$PROJ/docs/design/manifest.yaml" > "$SANDBOX/dup-manifest.yaml"
mkdir -p "$SANDBOX/dupproj/docs/design"
cp "$SANDBOX/dup-manifest.yaml" "$SANDBOX/dupproj/docs/design/manifest.yaml"
check_rc "invalid manifest -> 4" 4 "$SCOPE" --validate --root "$SANDBOX/dupproj"

echo "== --elements =="
check "one row per element, unfiltered" "4" "$("$SCOPE" --elements --root "$PROJ" | wc -l | tr -d ' ')"
check "screen filter narrows to that screen's elements" "1" "$("$SCOPE" --elements --root "$PROJ" --screen UI-SHELL | wc -l | tr -d ' ')"
check_rc "missing manifest -> 3" 3 "$SCOPE" --elements --root "$SANDBOX/nowhere"

echo "== --locate =="
check_rc "unknown element -> 3" 3 "$SCOPE" --locate UI-NOPE --root "$PROJ"
check_rc "no candidate anywhere -> 3" 3 "$SCOPE" --locate UI-SHELL-NAV --root "$PROJ"
printf 'export const Nav = () => <nav data-ui-id="UI-SHELL-NAV">Hauptnavigation</nav>;\n' > "$PROJ/src/Nav.tsx"
OUT="$("$SCOPE" --locate UI-SHELL-NAV --root "$PROJ")"
check "tier A hit once the code exists" "1" "$(printf '%s\n' "$OUT" | grep -c '^A	src/Nav.tsx:1$')"

echo "== --scope =="
check "no git changes -> every screen in scope" "2" "$("$SCOPE" --scope --root "$PROJ" | wc -l | tr -d ' ')"
git -C "$PROJ" add -A >/dev/null 2>&1 || true
git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q -m init >/dev/null 2>&1 || true
printf '<html>changed</html>\n' > "$PROJ/docs/design/mockups/ui-orders.html"
check "only the screen whose artboard changed is in scope" "1" "$("$SCOPE" --scope --root "$PROJ" | wc -l | tr -d ' ')"
check "and it's the right one" "UI-ORDERS" "$("$SCOPE" --scope --root "$PROJ")"
printf '\nrevision: 4\n' >> "$PROJ/docs/design/manifest.yaml"
check "a manifest.yaml change widens scope back to every screen" "2" "$("$SCOPE" --scope --root "$PROJ" | wc -l | tr -d ' ')"

echo "== --tokens =="
printf '.x { color: #ff00aa; }\n' > "$PROJ/src/rogue.css"
check "raw hex value outside tokens.css is reported" "1" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'rogue.css.*#ff00aa')"
check "tokens.css itself is never flagged" "0" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'mockups/tokens.css')"

echo "== --fix-scope =="
check "fix-scope lists web globs" "1" "$("$SCOPE" --fix-scope --root "$PROJ" | grep -c '\*\*/\*\.tsx')"

echo "== --check-seam =="
printf 'UI-X | tier=A | render=- | binding=- | source=- | handler=- | terminal=- | found=x | violated\n' > "$SANDBOX/seam.txt"
check "wired through to mb_check_seam" "1" "$("$SCOPE" --check-seam "$SANDBOX/seam.txt" --root "$PROJ" | grep -c 'unverified:no-locator$')"
check_rc "--check-seam without a file -> usage (2)" 2 "$SCOPE" --check-seam --root "$PROJ"

echo "== --seam-to-coverage =="
"$SCOPE" --check-seam "$SANDBOX/seam.txt" --root "$PROJ" > "$SANDBOX/seam-checked.txt"
check "bridge wired through (after --check-seam)" "UI-X | semantic | unverified:no-locator | -" "$("$SCOPE" --seam-to-coverage "$SANDBOX/seam-checked.txt" --stage semantic)"
check_rc "bridge without --stage -> usage (2)" 2 "$SCOPE" --seam-to-coverage "$SANDBOX/seam.txt"

echo "== --coverage =="
printf 'UI-ORDERS-TABLE | structure | ok | -\nUI-ORDERS-EMPTY | structure | ok | -\nUI-SHELL-NAV | structure | ok | -\n' > "$SANDBOX/cov.txt"
check_rc "fully covered -> exit 0 (MATCH)" 0 "$SCOPE" --coverage "$SANDBOX/cov.txt" --root "$PROJ"
: > "$SANDBOX/cov-empty.txt"
check_rc "nothing covered -> exit 1 (MISMATCH)" 1 "$SCOPE" --coverage "$SANDBOX/cov-empty.txt" --root "$PROJ"
check_rc "missing manifest -> 3" 3 "$SCOPE" --coverage "$SANDBOX/cov.txt" --root "$SANDBOX/nowhere"

echo "== --self-test =="
check_rc "self-test passes" 0 "$SCOPE" --self-test

summary "run-scope-tests"
