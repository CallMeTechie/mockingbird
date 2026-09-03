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

mb_adapter_token_sources() {
	printf '**/*.css\t(#[0-9a-fA-F]{3,8}\\b|\\b[0-9]+px\\b|font-family\\s*:)\n'
}
