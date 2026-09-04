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
mkdir -p "$PROJ/client/styles"
printf '.x\n  color: #ff00aa\n' > "$PROJ/client/styles/rogue.sass"
printf '$primary: #314BD3\n' > "$PROJ/client/styles/_colors.sass"
printf '.y { color: #abcdef; }\n' > "$PROJ/client/styles/brand.scss"
printf 'export const B = () => <b style={{ color: "#123456" }}>x</b>;\n' > "$PROJ/src/Inline.tsx"
printf 'const palette = ["#111111"];\n' > "$PROJ/src/Data.tsx"
check "raw value in .sass is reported" "1" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'rogue.sass.*#ff00aa')"
check "raw value in .scss is reported" "1" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'brand.scss')"
check "_colors.sass (definition file by name) is never flagged" "0" "$("$SCOPE" --tokens --root "$PROJ" | grep -c '_colors.sass')"
check "inline style raw value in tsx is reported" "1" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'Inline.tsx')"
check "a hex literal outside style= in tsx is not a token finding" "0" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'Data.tsx')"
printf 'token_definitions: [client/styles/brand.scss]\n' >> "$PROJ/docs/design/manifest.yaml"
check "files listed in token_definitions: are excluded" "0" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'brand.scss')"
printf '.z { padding: 4px; border: 1px solid; }\n' > "$PROJ/client/styles/px.css"
check "px values are not flagged (too common, mostly right)" "0" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'px.css')"
mkdir -p "$PROJ/client/public/fonts"; printf '@font-face { font-family: "Hack"; }\n' > "$PROJ/client/public/fonts/hack.css"
check "@font-face files are definition files, not findings" "0" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'hack.css')"
mkdir -p "$PROJ/landing/styles"; printf '.l { color: #999999; }\n' > "$PROJ/landing/styles/x.css"
check "without source_roots the whole project is scanned" "1" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'landing/')"
printf 'source_roots: [client]\n' >> "$PROJ/docs/design/manifest.yaml"
check "with source_roots only those directories are scanned" "0" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'landing/')"
check "source_roots still finds the in-scope raw value" "1" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'rogue.sass')"
printf 'export const Nav2 = () => <nav data-ui-id="UI-SHELL-NAV">x</nav>;\n' > "$PROJ/client/Nav2.tsx"
check "--locate honours source_roots and keeps root-relative paths" "1" "$("$SCOPE" --locate UI-SHELL-NAV --root "$PROJ" | grep -c "^A"$'\t'"client/Nav2.tsx:1$")"
printf '.f\n  color: var(--error-color, #d9534f)\n' > "$PROJ/client/styles/fallback.sass"
printf ':root{--x:1; --rogue-match: #ff00aa; --white: #ffffff; --text: #FFFFFF; --short: #abc;}\n' > "$PROJ/docs/design/mockups/tokens.css"
printf '$primary: #314BD3\n--sassy: #123456\n' > "$PROJ/client/styles/_colors.sass"
sed -i 's|^token_definitions: .*|token_definitions: [client/styles/brand.scss, client/styles/_colors.sass]|' "$PROJ/docs/design/manifest.yaml"
printf '.w { color: #FFFFFF; }\n.s { color: #aabbcc; }\n.p { color: #314bd3; }\n.n { color: #000001; }\n' > "$PROJ/client/styles/match.css"
check "raw value with exactly one token -> token named" "1" "$("$SCOPE" --tokens --root "$PROJ" | grep -cE 'rogue\.sass:[0-9]+:--rogue-match:')"
check "value shared by two tokens -> ambiguous" "1" "$("$SCOPE" --tokens --root "$PROJ" | grep -cF 'match.css:1:ambiguous:--white|--text:')"
check "3-digit token hex expands to match a 6-digit raw value" "1" "$("$SCOPE" --tokens --root "$PROJ" | grep -cF 'match.css:2:--short:')"
check "sass \$variable definitions count as tokens (case-insensitive)" "1" "$("$SCOPE" --tokens --root "$PROJ" | grep -cF 'match.css:3:$primary:')"
printf 'export const C = () => <i style={{ color: "#123456" }}>y</i>;\n' > "$PROJ/client/Inline2.tsx"   # inside source_roots
check "inline style value resolves to a sass-defined custom property" "1" "$("$SCOPE" --tokens --root "$PROJ" | grep -cF 'client/Inline2.tsx:1:--sassy:')"
printf ':root{--font-mono: "JetBrains Mono", ui-monospace, monospace; --type-mono: 400 0.875rem/1.5 var(--font-mono); --font-sans: "Plus Jakarta Sans", sans-serif;}\n' >> "$PROJ/docs/design/mockups/tokens.css"
printf '.m\n  font-family: monospace\n.n\n  font-family: "Fira Code", monospace\n.s\n  font-family: Inter, sans-serif\n' > "$PROJ/client/styles/fonts.sass"
check "font-family: monospace -> the one family token, not the size-bearing shorthand" "2" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'fonts.sass:[0-9]*:--font-mono:')"
check "font-family sans-serif -> --font-sans" "1" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'fonts.sass:[0-9]*:--font-sans:')"
check "raw value with no token -> -" "1" "$("$SCOPE" --tokens --root "$PROJ" | grep -cF 'match.css:4:-:')"
# --error-color is nowhere defined in this fixture, so the "fallback" is what
# the browser actually paints -- hiding it would be a silent pass. The rule is
# about whether the property exists, not about the var() syntax.
check "var(--x, raw) is reported when --x is defined NOWHERE" "1" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'fallback.sass')"
printf '.g\n  color: var(--rogue-match, #ff00aa)\n' > "$PROJ/client/styles/realfallback.sass"
check "var(--x, raw) stays silent when --x IS defined" "0" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'realfallback.sass')"
printf '.h\n  color: var(--from-js, #ff00aa)\n' > "$PROJ/client/styles/jsfallback.sass"
printf 'el.style.setProperty("--from-js", theme.accent);\n' > "$PROJ/client/theme.js"
check "a property set through setProperty() counts as defined" "0" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'jsfallback.sass')"

echo "== --tokens: functional colour notations =="
# Outpost defines its whole grey scale as rgba(), so a hex-only scan was blind
# to the most-copied values in the project.
printf '.i\n  border-color: rgba(255, 255, 255, 0.2)\n  background: hsl(210, 40%%, 12%%)\n' > "$PROJ/client/styles/func.sass"
printf ':root{--gray-strong: rgba(255,255,255,0.2);}\n' >> "$PROJ/docs/design/mockups/tokens.css"
check "rgba() with literal numbers is a raw value" "1" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'func.sass.*rgba')"
check "and the matching token is named despite the spacing" "1" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'func.sass.*--gray-strong')"
check "hsl() with literal numbers is a raw value too" "1" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'func.sass.*hsl')"
printf '.j\n  background: rgba(colors.$primary, 0.7)\n' > "$PROJ/client/styles/sassvar.sass"
check "rgba() around a variable is a token in use, not a raw value" "0" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'sassvar.sass')"
check "definition files keep their own rgba values unflagged" "0" "$("$SCOPE" --tokens --root "$PROJ" | grep -c 'mockups/tokens.css')"
check "--locate under source_roots ignores files outside" "0" "$("$SCOPE" --locate UI-SHELL-NAV --root "$PROJ" | grep -c 'src/Nav.tsx')"

echo "== --fix-scope =="
check "fix-scope lists web globs" "1" "$("$SCOPE" --fix-scope --root "$PROJ" | grep -c '\*\*/\*\.tsx')"
check "fix-scope also allows stylesheets (token fixes live there)" "1" "$("$SCOPE" --fix-scope --root "$PROJ" | grep -c '^\*\*/\*\.sass$')"
check "fix-scope excludes the token mirror" "1" "$("$SCOPE" --fix-scope --root "$PROJ" | grep -c '^!docs/design/mockups/tokens.css$')"
check "fix-scope excludes token_definitions files" "1" "$("$SCOPE" --fix-scope --root "$PROJ" | grep -c '^!client/styles/_colors.sass$')"
check "fix-scope lists no glob twice" "0" "$("$SCOPE" --fix-scope --root "$PROJ" | grep -v '^!' | sort | uniq -d | wc -l | tr -d ' ')"

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
printf 'UI-SHELL-NAV | structure | ok | -\n' > "$SANDBOX/cov-shell.txt"
check_rc "--coverage --screen scopes the denominator (0)" 0 "$SCOPE" --coverage "$SANDBOX/cov-shell.txt" --root "$PROJ" --screen UI-SHELL
check_rc "missing manifest -> 3" 3 "$SCOPE" --coverage "$SANDBOX/cov.txt" --root "$SANDBOX/nowhere"

echo "== --healthcheck =="
# Named, never run: the caller decides about timeouts and permissions.
mkdir -p "$PROJ/client"
cat > "$PROJ/client/package.json" <<'PKG'
{ "name": "c", "scripts": { "lint": "eslint .", "build": "vite build" } }
PKG
mkdir -p "$PROJ/landing"
cat > "$PROJ/landing/package.json" <<'PKG'
{ "name": "l", "scripts": { "lint": "eslint ." } }
PKG
cat > "$PROJ/package.json" <<'PKG'
{ "name": "root", "scripts": { "lint": "eslint server scripts", "test": "node --test" } }
PKG
HCOUT="$("$SCOPE" --healthcheck --root "$PROJ" 2>/dev/null)"
check "healthcheck names at least one lint command" "yes" "$([ "$(printf '%s\n' "$HCOUT" | grep -c 'eslint')" -ge 1 ] && echo yes || echo no)"
check "each line carries its whole|files scope" "0" "$(printf '%s\n' "$HCOUT" | grep -vcE $'\t(whole|files)$')"
check "source_roots narrow it to the package the screens live in" "0" "$(printf '%s\n' "$HCOUT" | grep -c '^landing	')"
# A monorepo keeps its whole test suite at the top; a client-only scan would
# never see it, and a run that changes server code has to.
check "a root command of a kind no package offers is kept" "1" "$(printf '%s\n' "$HCOUT" | grep -c '^\.	npm run --silent test	whole$')"
# Run from the root a linter sees every package; run from one package it sees
# only that package, and this stage hands it paths from anywhere.
# Which paths a linter really covers is its config's business, not this
# script's: Outpost's root config matches server/ and scripts/ only and calls a
# client file "ignored". Keeping just one of the two silently stops linting half
# the repo, so both are offered and the caller runs both.
check "the root file-scoped linter is offered" "1" "$(printf '%s\n' "$HCOUT" | grep -c '^\.	npx eslint	files$')"
check "and the package one is kept alongside it" "1" "$(printf '%s\n' "$HCOUT" | grep -c '^client	npx eslint	files$')"
check "the package build still stands on its own" "1" "$(printf '%s\n' "$HCOUT" | grep -c '^client	npm run --silent build	whole$')"
check_rc "healthcheck without a manifest -> 3" 3 "$SCOPE" --healthcheck --root "$SANDBOX/nowhere"
rm -rf "$PROJ/client" "$PROJ/landing" "$PROJ/package.json"
check_rc "no runnable command in the project -> 3 (not a silent pass)" 3 "$SCOPE" --healthcheck --root "$PROJ"

echo "== --self-test =="
check_rc "self-test passes" 0 "$SCOPE" --self-test

summary "run-scope-tests"
