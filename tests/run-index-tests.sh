#!/usr/bin/env bash
# mb-render-index.sh: the contact sheet — summaries from the manifest, the
# artboards embedded as style-scoped excerpts, never as iframes.
set -u
# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(dirname -- "$HERE")"
. "$HERE/_helper.sh"
GEN="$ROOT/plugin/scripts/mb-render-index.sh"

sandbox
P="$SANDBOX/proj"; mkdir -p "$P/docs/design/mockups"
cp "$ROOT/tests/fixtures/manifest/valid.yaml" "$P/docs/design/manifest.yaml"
printf '# ds\n' > "$P/docs/design/design-system.md"; : > "$P/docs/design/mockups/tokens.css"
cat > "$P/docs/design/mockups/ui-orders.html" <<'HTML'
<!doctype html><html><head><style>
/* a comment that must not become a selector */
body { margin: 0; background: red; }
.tab, .tab:hover { color: blue; }
@media (max-width: 40rem) { .tab { display: none; } }
@keyframes pulse { from { opacity: 0 } to { opacity: 1 } }
</style></head><body><main class="mb-artboard"><h2>inside</h2><div class="tab" data-ui-id="UI-ORDERS-TABLE">x</div></main><script>alert(1)</script></body></html>
HTML
printf '<!doctype html><html><head><style>.nav{color:green}</style></head><body><nav data-ui-id="UI-SHELL-NAV"></nav></body></html>\n' > "$P/docs/design/mockups/ui-shell.html"

check_rc "usage without --root -> 2" 2 "$GEN"
check_rc "missing manifest -> 3" 3 "$GEN" --root "$SANDBOX/nowhere"
check_rc "renders" 0 "$GEN" --root "$P"
OUT="$P/docs/design/mockups/index.html"
check "index written" "1" "$([ -f "$OUT" ] && echo 1 || echo 0)"
check "no iframe anywhere" "0" "$(grep -c '<iframe' "$OUT")"
check "one embed per artboard" "2" "$(grep -c 'class="mb-embed"' "$OUT")"
check "one section per screen" "2" "$(grep -c '^<h2 id="UI-' "$OUT")"
check "element rows carry anchors" "1" "$(grep -c 'UI-ORDERS-TABLE.*Nicht:</b> invoice, shipment' "$OUT")"
check "body rule became the wrapper" "1" "$(grep -c '^#ab-ui-orders{ margin: 0' "$OUT")"
check "selector list prefixed per selector" "1" "$(grep -c '^#ab-ui-orders \.tab, #ab-ui-orders \.tab:hover{' "$OUT")"
check "@media inner rule prefixed" "1" "$(grep -c '@media (max-width: 40rem){#ab-ui-orders \.tab{' "$OUT" | tr -d ' ')"
check "@keyframes kept verbatim" "1" "$(grep -c '@keyframes pulse{' "$OUT")"
check "CSS comment did not become a selector" "0" "$(grep -c 'must not become' "$OUT")"
check "scripts stripped from embeds" "0" "$(grep -c 'alert(1)' "$OUT")"
check "embedded markup present" "1" "$(grep -c 'data-ui-id="UI-ORDERS-TABLE"' "$OUT")"
check "page styles are direct-child scoped" "0" "$(grep -cE '^\.mb-page (h1|h2|table|\.ctx) ' "$OUT")"
sed 's/UI-ORDERS-EMPTY/UI-ORDERS-TABLE/' "$ROOT/tests/fixtures/manifest/valid.yaml" > "$P/docs/design/manifest.yaml"
check_rc "invalid manifest -> 4" 4 "$GEN" --root "$P"
summary "run-index-tests"
