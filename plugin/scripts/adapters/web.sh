# shellcheck shell=bash
# Web adapter (React/Vue/Svelte/plain HTML). The only adapter fully
# implemented in v0.1 — see references/adapters/{tui,desktop,mobile}.md for
# the documented-but-not-implemented others.
#
# Contract (four functions, the whole adapter surface — see
# skills/verifying-against-mockup/references/adapters/web.md for the prose
# half of this contract):
#   mb_adapter_globs                       -> path patterns, one per line
#   mb_adapter_locate <element-id> <label> -> "tier<TAB>file:line", one per line
#   mb_adapter_capabilities                -> "key=yes|no", one per line
#   mb_adapter_token_sources               -> "css-file-glob<TAB>raw-value-regex"

mb_adapter_globs() {
	cat <<'GLOBS'
**/*.tsx
**/*.jsx
**/*.vue
**/*.svelte
**/*.html
GLOBS
}

# Locator search, cheapest and most certain first. Every candidate line is
# "tier<TAB>file:line" so the caller can cap severity by tier without ever
# re-deriving it. Only greps -- no parsing, no false confidence from a
# clever-looking match. Exit 3 if nothing at all was found (distinct from "0
# results, nothing to report" so callers can tell "found nothing" apart from
# "adapter itself is broken").
mb_adapter_locate() {
	local id="$1" label="$2" root="${MB_ADAPTER_ROOT:-.}" any=0 f

	# Tier A: an explicit data-ui-id marker. Certain -- this plugin's own
	# artboard-writer agent emits exactly this attribute.
	while IFS= read -r f; do
		[ -n "$f" ] || continue
		while IFS=: read -r ln _; do
			[ -n "$ln" ] || continue
			printf 'A\t%s:%s\n' "${f#"$root"/}" "$ln"
			any=1
		done < <(grep -nF -- "data-ui-id=\"$id\"" "$f" 2>/dev/null; grep -nF -- "data-ui-id='$id'" "$f" 2>/dev/null)
	done < <(_mb_web_candidate_files "$root")

	# Tier B: an unambiguous match of the label string itself.
	if [ -n "$label" ]; then
		while IFS= read -r f; do
			[ -n "$f" ] || continue
			while IFS=: read -r ln _; do
				[ -n "$ln" ] || continue
				printf 'B\t%s:%s\n' "${f#"$root"/}" "$ln"
				any=1
			done < <(grep -nF -- "$label" "$f" 2>/dev/null)
		done < <(_mb_web_candidate_files "$root")
	fi

	# Tier C: naming-convention fuzz match on the element id's last segment,
	# e.g. UI-ORDERS-TABLE -> a symbol containing "Table" (case-insensitive).
	local seg
	seg="${id##*-}"
	if [ -n "$seg" ] && [ "${#seg}" -ge 3 ]; then
		while IFS= read -r f; do
			[ -n "$f" ] || continue
			while IFS=: read -r ln _; do
				[ -n "$ln" ] || continue
				printf 'C\t%s:%s\n' "${f#"$root"/}" "$ln"
				any=1
			done < <(grep -niF -- "$seg" "$f" 2>/dev/null)
		done < <(_mb_web_candidate_files "$root")
	fi

	[ "$any" -eq 1 ] || return 3
	return 0
}

_mb_web_candidate_files() {
	local root="$1"
	find "$root" \
		\( -path '*/node_modules/*' -o -path '*/dist/*' -o -path '*/build/*' -o -path '*/.git/*' \) -prune -o \
		-type f \( -name '*.tsx' -o -name '*.jsx' -o -name '*.vue' -o -name '*.svelte' -o -name '*.html' \) -print \
		2>/dev/null
}

mb_adapter_capabilities() {
	cat <<'CAPS'
structure=yes
semantic=yes
states=yes
tokens=yes
flow=yes
visual=no
runtime=no
CAPS
}

# One "glob<TAB>raw-value regex" line per source kind. Stylesheet dialects
# first (a project on Sass would otherwise be invisible to the tokens stage --
# found on Outpost, 2026-09-04: 14 .sass files with raw hex values that a
# css-only scan never saw), then inline style attributes in components, where
# a raw value hides just as easily. Token *definition* files are excluded by
# the caller (manifest token_definitions: + tokens_css + the _colors/_tokens/
# _variables naming convention), not here. px values are deliberately NOT
# flagged: they are everywhere (1px borders, line-heights) and mostly right;
# flagging them buried the real findings under 1700 lines on Outpost.
mb_adapter_token_sources() {
	cat <<'SRC'
**/*.css	(#[0-9a-fA-F]{3,8}\b|font-family\s*:)
**/*.sass	(#[0-9a-fA-F]{3,8}\b|font-family\s*:)
**/*.scss	(#[0-9a-fA-F]{3,8}\b|font-family\s*:)
**/*.less	(#[0-9a-fA-F]{3,8}\b|font-family\s*:)
**/*.tsx	style=\{?\{?[^}]*#[0-9a-fA-F]{3,8}\b
**/*.jsx	style=\{?\{?[^}]*#[0-9a-fA-F]{3,8}\b
**/*.vue	style="[^"]*#[0-9a-fA-F]{3,8}\b
**/*.svelte	style="[^"]*#[0-9a-fA-F]{3,8}\b
SRC
}
