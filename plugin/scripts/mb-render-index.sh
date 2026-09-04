#!/usr/bin/env bash
# Generate docs/design/mockups/index.html — the contact sheet — from the
# manifest and the artboards. Per screen: kind and presentation context,
# description, element table with business anchors, states, links to the
# artboard and the implementation guide, then the artboard itself embedded
# as a style-scoped excerpt. No <iframe>: over file:// frames are often
# blank, and a frame catalogue without commentary explains nothing
# (feedback from the first live dialogue, 2026-09-03).
#
# Style scoping: each artboard's <style> is copied with every selector
# prefixed by "#ab-<slug>"; body/html/:root selectors become the wrapper
# itself. @media blocks are handled one level deep; @keyframes/@font-face are
# copied verbatim. This is why artboard-conventions.md asks for flat CSS.
#
# Usage: mb-render-index.sh --root DIR [--out FILE]
# Exit: 0 ok · 2 usage · 3 manifest/artboard missing · 4/5 manifest invalid
set -u
# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PLUGIN_ROOT="$(dirname -- "$HERE")"
. "$PLUGIN_ROOT/lib/mockingbird-manifestlib.sh"

ROOT="" OUT=""
while [ $# -gt 0 ]; do
	case "$1" in
		--root) ROOT="$2"; shift 2 ;;
		--out) OUT="$2"; shift 2 ;;
		*) echo "usage: mb-render-index.sh --root DIR [--out FILE]" >&2; exit 2 ;;
	esac
done
[ -n "$ROOT" ] || { echo "usage: --root is required" >&2; exit 2; }
MANIFEST="$ROOT/docs/design/manifest.yaml"
[ -f "$MANIFEST" ] || { echo "no manifest at $MANIFEST" >&2; exit 3; }
[ -n "$OUT" ] || OUT="$ROOT/docs/design/mockups/index.html"

ERR="$(MB_VALIDATE_ROOT="$ROOT" mb_manifest_validate "$MANIFEST" 2>&1 1>/dev/null)"; RC=$?
if [ "$RC" -ne 0 ]; then [ -n "$ERR" ] && printf '%s\n' "$ERR" >&2; case "$RC" in 6) exit 4 ;; *) exit "$RC" ;; esac; fi

META="$(mb_manifest_meta "$MANIFEST")"
meta_get() { printf '%s\n' "$META" | awk -F'\t' -v k="$1" '$1==k{print $2; exit}'; }
PROJECT="$(meta_get project)"; REV="$(meta_get revision)"; UPDATED="$(meta_get updated)"
SYS="$(meta_get design_system)"; TOKENS="$(meta_get tokens_css)"
TSV="$(mb_manifest_to_tsv "$MANIFEST")"

# screen-level scalars the TSV does not carry (title, description, guide,
# presentation): read them from the manifest with a small awk that only
# looks at 4-space-indented keys under the current "  - id:" item.
screen_scalar() {
	awk -v want="$1" -v key="$2" '
		/^  - id:/ { cur=$0; sub(/^  - id:[ \t]*/,"",cur) }
		cur==want && $0 ~ ("^    " key ":") { v=$0; sub("^    " key ":[ \t]*","",v); gsub(/^"|"$/,"",v); print v; exit }
	' "$MANIFEST"
}
pres_get() { # pres_get "<flow map>" key
	printf '%s' "$1" | awk -v k="$2" 'BEGIN{RS="[,{}]"} { s=$0; sub(/^[ \t]+/,"",s); if (index(s, k ":")==1) { s=substr(s, length(k)+2); sub(/^[ \t]+/,"",s); gsub(/^"|"$/,"",s); print s; exit } }'
}
html_esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

# Scope one artboard's CSS to #ab-<slug>. Reads the <style> body on stdin.
scope_css() {
	awk -v pfx="#ab-$1" '
		function prefix(sel,    n, parts, i, out, s) {
			n = split(sel, parts, ",")
			out = ""
			for (i = 1; i <= n; i++) {
				s = parts[i]; gsub(/^[ \t\n]+|[ \t\n]+$/, "", s)
				if (s == "") continue
				if (s == "body" || s == "html" || s == ":root" || s == "html, body" || s == "body, html") s = pfx
				else if (s ~ /^(body|html)[ >]/) { sub(/^(body|html)/, pfx, s) }
				else s = pfx " " s
				out = out (out == "" ? "" : ", ") s
			}
			return out
		}
		{
			buf = buf $0 "\n"
		}
		END {
			gsub(/\/\*[^*]*\*+([^\/*][^*]*\*+)*\//, "", buf)   # drop comments: they would ride along as selector text
			n = length(buf); i = 1; depth = 0; sel = ""; verbatim = 0
			while (i <= n) {
				c = substr(buf, i, 1)
				if (c == "{") {
					s = sel; gsub(/^[ \t\n]+|[ \t\n]+$/, "", s)
					if (depth == 0 && s ~ /^@(keyframes|font-face|-webkit-keyframes)/) { verbatim = 1; printf "%s{", s }
					else if (s ~ /^@/) { printf "%s{", s }      # @media etc.: keep, prefix inner rules
					else if (verbatim) { printf "%s{", s }
					else printf "%s{", prefix(s)
					depth++; sel = ""
				} else if (c == "}") {
					depth--; printf "}\n"; if (depth == 0) verbatim = 0; sel = ""
				} else if (depth > 0 && verbatim) {
					printf "%s", c
				} else if (depth > 0 && sel == "" && c != "\n") {
					# inside a block: declarations go through untouched until next selector/brace
					j = i; decl = ""
					while (j <= n) { d = substr(buf, j, 1); if (d == "{" || d == "}") break; decl = decl d; j++ }
					if (substr(buf, j, 1) == "{") { sel = decl; i = j; continue }
					printf "%s", decl; i = j; continue
				} else {
					sel = sel c
				}
				i++
			}
		}'
}

{
cat <<HDR
<!doctype html>
<html lang="de" data-theme="dark">
<head>
<meta charset="utf-8">
<title>$(printf '%s' "$PROJECT" | html_esc) — Mockups (Revision $REV)</title>
<link rel="stylesheet" href="./$(basename "$TOKENS")">
<style>
.mb-page { font: var(--type-body, 500 0.875rem/1.45 system-ui, sans-serif); color: var(--text, #eee); background: var(--background, #111); margin: 0; padding: var(--space-8, 2rem); }
.mb-page > h1 { font: var(--type-title, 700 1.25rem/1.3 system-ui); margin: 0 0 .5rem; }
.mb-page > h2 { font: var(--type-heading, 600 1rem/1.4 system-ui); margin: 2.5rem 0 .5rem; padding-top: 1.5rem; border-top: 1px solid var(--gray, #333); }
.mb-page > .sub, .mb-page > .meta { color: var(--subtext, #aaa); }
.mb-page > .ctx { background: var(--lighter-background, #1a1a1a); border: 1px solid var(--gray, #333); border-radius: var(--radius-md, .5rem); padding: .75rem 1rem; margin: .75rem 0; line-height: 1.6; }
.mb-page > table { border-collapse: collapse; width: 100%; margin: .75rem 0; font: var(--type-caption, 500 0.75rem/1.4 system-ui); }
.mb-page > table th, .mb-page > table td { text-align: left; vertical-align: top; padding: .35rem .5rem; border-bottom: 1px solid var(--gray, #333); }
.mb-page > table th { color: var(--subtext, #aaa); font-weight: 600; }
.mb-page > p code, .mb-page > table code, .mb-page > h2 code, .mb-page > .ctx code, .mb-page > .mb-toc code { font: var(--type-mono, 400 0.8rem monospace); color: var(--subtext, #aaa); }
.mb-page > p a, .mb-page > .mb-toc a { color: var(--primary, #4b7bff); }
.mb-embed { border: 1px solid var(--gray, #333); border-radius: var(--radius-lg, .75rem); overflow: hidden; margin: 1rem 0 0; }
.mb-embed-label { font: var(--type-caption, 500 .75rem system-ui); color: var(--subtext, #aaa); padding: .4rem .75rem; background: var(--lighter-background, #1a1a1a); border-bottom: 1px solid var(--gray, #333); }
.mb-toc { list-style: none; padding: 0; display: flex; flex-wrap: wrap; gap: .5rem 1.25rem; }
</style>
HDR
# scoped styles of every artboard
printf '%s\n' "$TSV" | cut -f1,3 | sort -u | while IFS=$'\t' read -r sid art; do
	[ "$art" != "-" ] && [ -f "$ROOT/$art" ] || continue
	slug="$(basename "$art" .html)"
	printf '<style>\n/* %s */\n' "$slug"
	awk '/<style[^>]*>/{f=1; sub(/.*<style[^>]*>/,""); } /<\/style>/{ if(f){sub(/<\/style>.*/,""); print; f=0} next } f' "$ROOT/$art" | scope_css "$slug"
	printf '\n</style>\n'
done
cat <<BODY
</head>
<body class="mb-page">
<h1>$(printf '%s' "$PROJECT" | html_esc) — Mockups</h1>
<p class="sub">Manifest-Revision $REV · $UPDATED · Quelle der Wahrheit: <code>docs/design/manifest.yaml</code> · Design-System: <code>$SYS</code>. Jedes Artboard zeigt alle deklarierten Zustände gestapelt; die Kopfzeile jedes Artboards erklärt, wie und wo der Screen erscheint.</p>
<ul class="mb-toc">
BODY
printf '%s\n' "$TSV" | cut -f1 | awk '!seen[$0]++' | while read -r sid; do
	t="$(screen_scalar "$sid" title)"; printf '<li><a href="#%s">%s</a> <code>%s</code></li>\n' "$sid" "$(printf '%s' "${t:-$sid}" | html_esc)" "$sid"
done
echo '</ul>'

printf '%s\n' "$TSV" | cut -f1 | awk '!seen[$0]++' | while read -r sid; do
	title="$(screen_scalar "$sid" title)"; kind="$(screen_scalar "$sid" kind)"; desc="$(screen_scalar "$sid" description)"
	guide="$(screen_scalar "$sid" guide)"; route="$(screen_scalar "$sid" route_hint)"; pres="$(screen_scalar "$sid" presentation)"
	art="$(printf '%s\n' "$TSV" | awk -F'\t' -v s="$sid" '$1==s{print $3; exit}')"
	case "$kind" in page) kindde="Seite" ;; dialog) kindde="Dialog (modal, mit Backdrop)" ;; panel) kindde="Panel" ;; overlay) kindde="Overlay" ;; shared) kindde="Shell (auf jedem Screen)" ;; *) kindde="$kind" ;; esac
	printf '<h2 id="%s">%s <code>%s</code></h2>\n' "$sid" "$(printf '%s' "${title:-$sid}" | html_esc)" "$sid"
	[ -n "$desc" ] && printf '<p>%s</p>\n' "$(printf '%s' "$desc" | html_esc)"
	printf '<div class="ctx"><b>Art:</b> %s' "$kindde"
	[ -n "$route" ] && printf ' · Route <code>%s</code>' "$(printf '%s' "$route" | html_esc)"
	if [ -n "$pres" ]; then
		for k in over trigger size dismiss keyboard; do
			v="$(pres_get "$pres" "$k")"; [ -n "$v" ] || continue
			case "$k" in over) l="Erscheint über" ;; trigger) l="Öffnen durch" ;; size) l="Größe" ;; dismiss) l="Schließen" ;; keyboard) l="Tastatur" ;; esac
			printf '<br><b>%s:</b> %s' "$l" "$(printf '%s' "$v" | html_esc)"
		done
	fi
	printf '</div>\n'
	printf '<p class="meta">Artboard: <a href="./%s">%s</a>' "$(basename "$art")" "$(basename "$art")"
	[ -n "$guide" ] && printf ' · Umsetzungsanleitung: <code>%s</code>' "$(printf '%s' "$guide" | html_esc)"
	printf '</p>\n<table><tr><th>ID</th><th>Element</th><th>Fachlicher Anker</th><th>Zustände</th></tr>\n'
	printf '%s\n' "$TSV" | awk -F'\t' -v s="$sid" '$1==s' | while IFS=$'\t' read -r _ _ _ id _ label _ _ _ means _ _ notl states _ _ _ _; do
		anchor="$means"; [ "$anchor" = "-" ] && anchor=""
		[ "$notl" != "-" ] && anchor="${anchor:+$anchor }<b>Nicht:</b> $(printf '%s' "$notl" | sed 's/,/, /g')."
		printf '<tr><td><code>%s</code></td><td>%s</td><td>%s</td><td><code>%s</code></td></tr>\n' "$id" "$(printf '%s' "$label" | html_esc)" "$anchor" "$(printf '%s' "$states" | sed 's/,/ · /g')"
	done
	echo '</table>'
	if [ "$art" != "-" ] && [ -f "$ROOT/$art" ]; then
		slug="$(basename "$art" .html)"
		printf '<div class="mb-embed"><div class="mb-embed-label">Auszug: %s — alle Zustände, wie im Artboard</div><div id="ab-%s">\n' "$(basename "$art")" "$slug"
		# body content without script tags
		awk '/<body[^>]*>/{f=1; sub(/.*<body[^>]*>/,"")} /<\/body>/{ if(f){sub(/<\/body>.*/,""); print}; f=0; next } f' "$ROOT/$art" | awk '
			# strip <script>…</script> even when it shares a line with markup
			{ line = $0; out = ""
			  while (1) {
				if (inscript) { e = index(line, "</script>"); if (!e) { line = ""; break } ; line = substr(line, e + 9); inscript = 0; continue }
				b = index(line, "<script"); if (!b) { out = out line; break }
				out = out substr(line, 1, b - 1); line = substr(line, b); inscript = 1
			  }
			  if (out != "" || !inscript) print out }'
		printf '</div></div>\n'
	fi
done
echo '</body></html>'
} > "$OUT.tmp" && mv -- "$OUT.tmp" "$OUT"
echo "wrote $OUT"
