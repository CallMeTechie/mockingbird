# shellcheck shell=bash
# Web adapter (React/Vue/Svelte/plain HTML). The only adapter fully
# implemented in v0.1 — see references/adapters/{tui,desktop,mobile}.md for
# the documented-but-not-implemented others.
#
# Contract (six functions, the whole adapter surface — see
# skills/verifying-against-mockup/references/adapters/web.md for the prose
# half of this contract):
#   mb_adapter_globs                       -> path patterns, one per line
#                                             (components: the locator's search
#                                             space. The editor's allowlist is
#                                             this UNION token_sources, minus
#                                             the token definition files --
#                                             assembled by --fix-scope, not here.)
#   mb_adapter_locate <element-id> <label> -> "tier<TAB>file:line", one per line
#   mb_adapter_capabilities                -> "key=yes|no", one per line
#   mb_adapter_token_sources               -> "css-file-glob<TAB>raw-value-regex"
#   mb_adapter_healthcheck <root>          -> "workdir<TAB>command<TAB>whole|files"
#   mb_adapter_runtime_css <root>          -> "file:line<TAB>mechanism"

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

	# Tier A: an explicit marker. Two spellings, both certain: the DOM attribute
	# data-ui-id="X", and the camelCase prop dataUiId="X" that a React component
	# takes when the marker has to be handed to a shared component which renders
	# the element (found on Outpost: a ContextMenu used by many screens).
	while IFS= read -r f; do
		[ -n "$f" ] || continue
		while IFS=: read -r ln _; do
			[ -n "$ln" ] || continue
			printf 'A\t%s:%s\n' "${f#"$root"/}" "$ln"
			any=1
		done < <(grep -nE -- "(data-ui-id|dataUiId)=\\{?[\"']${id}[\"']\\}?" "$f" 2>/dev/null)
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

# One "glob<TAB>raw-value regex" line per source kind. Functional colour
# notations count as raw values whenever they open with a digit: Outpost
# defines its entire grey scale as rgba() (--gray: rgba(255,255,255,0.1)),
# so a hex-only scan was blind to the most-copied values in the project --
# found 2026-09-04 by a reviewer who noticed the tool had reported nothing
# where four raw values sat. `rgba(colors.$x, .5)` does NOT open with a digit
# and stays unflagged: it is a token being used, however badly. Stylesheet dialects
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
**/*.css	(#[0-9a-fA-F]{3,8}\b|(rgba?|hsla?)\([0-9]|font-family\s*:)
**/*.sass	(#[0-9a-fA-F]{3,8}\b|(rgba?|hsla?)\([0-9]|font-family\s*:)
**/*.scss	(#[0-9a-fA-F]{3,8}\b|(rgba?|hsla?)\([0-9]|font-family\s*:)
**/*.less	(#[0-9a-fA-F]{3,8}\b|(rgba?|hsla?)\([0-9]|font-family\s*:)
**/*.tsx	style=\{?\{?[^}]*#[0-9a-fA-F]{3,8}\b
**/*.jsx	style=\{?\{?[^}]*#[0-9a-fA-F]{3,8}\b
**/*.vue	style="[^"]*#[0-9a-fA-F]{3,8}\b
**/*.svelte	style="[^"]*#[0-9a-fA-F]{3,8}\b
SRC
}

# Commands that prove the code still RUNS, one
# "workdir<TAB>command<TAB>whole|files" line each. It only names them; running
# them is the caller's job, so timeouts and permissions stay where the user can
# see them.
#
# The third column is what makes this usable on a real project. A repo-wide
# lint on an existing codebase is red before mockingbird touches anything
# (Outpost: 80 pre-existing errors), so as a gate it says nothing. "files"
# means the caller appends the paths it just changed; "whole" means the command
# is only meaningful across the whole package (a build, a typecheck) and runs
# as-is. For a file-scoped run the underlying tool is named directly -- an npm
# script like "eslint ." cannot be narrowed by appending a path, it would just
# lint everything and then the path.
#
# Why this is part of the adapter contract at all: mockingbird writes code (the
# fix path, the editor agent), and all five review stages read code as text.
# None of them notices a ReferenceError. Found on Outpost, 2026-09-04: a control
# built from the guide called t(...) in a component that never took the
# useTranslation hook — it would have crashed on render, and structure, flow
# and the seam check all passed it.
mb_adapter_healthcheck() {
	_mb_root="${1:-.}"
	# The manifest's source_roots are where components live; a monorepo keeps
	# its package.json next to them, not necessarily at the top.
	for _mb_dir in "$_mb_root" "$_mb_root"/*/; do
		[ -f "$_mb_dir/package.json" ] || continue
		_mb_rel="${_mb_dir%/}"
		_mb_rel="${_mb_rel#"$_mb_root"}"
		_mb_rel="${_mb_rel#/}"
		[ -n "$_mb_rel" ] || _mb_rel="."
		for _mb_script in lint typecheck test build; do
			# Read the script's value, not just its presence: a file-scoped
			# run needs the tool's own name, and an empty value means no script.
			_mb_val="$(awk -v want="$_mb_script" '
				/"scripts"[ \t]*:/ { in_s = 1 }
				in_s && $0 ~ "\"" want "\"[ \t]*:" {
					line = $0
					sub(".*\"" want "\"[ \t]*:[ \t]*\"", "", line)
					sub("\".*", "", line)
					print line
					exit
				}
				in_s && /^[ \t]*\}/ { in_s = 0 }
			' "$_mb_dir/package.json" 2>/dev/null)"
			[ -n "$_mb_val" ] || continue
			case "$_mb_script" in
				lint)
					# First word of the script IS the tool (eslint, biome,
					# oxlint, ...). Anything else and we cannot narrow safely,
					# so fall back to the whole-package run.
					_mb_tool="${_mb_val%% *}"
					case "$_mb_tool" in
						eslint|biome|oxlint|standard|xo)
							printf '%s\tnpx %s\tfiles\n' "$_mb_rel" "$_mb_tool" ;;
						*)
							printf '%s\tnpm run --silent %s\twhole\n' "$_mb_rel" "$_mb_script" ;;
					esac
					;;
				*)
					printf '%s\tnpm run --silent %s\twhole\n' "$_mb_rel" "$_mb_script" ;;
			esac
		done
	done
	unset _mb_root _mb_dir _mb_rel _mb_script _mb_val _mb_tool
}

# Stylesheets are not the last word on what the browser paints. A web app can
# append CSS at runtime -- a theme loader, a plugin system, a user stylesheet
# stored in its own database -- and that CSS lands after every <link> in the
# document, so at equal specificity it wins, and with !important it wins
# outright. None of the five stages can see it: it is not in the repository at
# all, it is in a row of the running app's data.
#
# So the adapter reports the MECHANISM, never a verdict. Runtime injection is
# perfectly legitimate; what is not legitimate is a MATCH that silently assumes
# it away. The caller names it as an open gap so a green verdict cannot be read
# as "the built UI looks like the artboard".
#
# Found on Outpost, 2026-09-04: UI-SERVERS stood at MATCH while every radius in
# the app was dead, because the account's active theme was one rule --
# `*, *::before, *::after { border-radius: 0 !important }` -- injected by
# ThemeLoader.jsx into document.body. Five stages, a seam check and a chromium
# render of the shipped CSS all agreed the corners were round. The user's
# screen disagreed, and the user was right.
mb_adapter_runtime_css() {
	_mb_root="${1:-.}"
	_mb_any=0

	# Only mechanisms that can carry a whole stylesheet. A single setProperty()
	# call sets one custom property and is already visible to --tokens, so it is
	# deliberately not reported here -- this is about rules, not values.
	while IFS=: read -r _mb_f _mb_l _mb_rest; do
		[ -n "$_mb_f" ] || continue
		case "$_mb_rest" in
			*createElement*style*)     _mb_kind="createElement(style)" ;;
			*insertRule*)              _mb_kind="insertRule" ;;
			*adoptedStyleSheets*)      _mb_kind="adoptedStyleSheets" ;;
			*dangerouslySetInnerHTML*) _mb_kind="style-dangerouslySetInnerHTML" ;;
			*)                         _mb_kind="runtime-css" ;;
		esac
		printf '%s:%s\t%s\n' "${_mb_f#"$_mb_root"/}" "$_mb_l" "$_mb_kind"
		_mb_any=1
	done <<EOF
$(grep -rnE 'createElement\((["'"'"'])style\1\)|\.insertRule\(|adoptedStyleSheets|<style[^>]*dangerouslySetInnerHTML' \
	--include='*.js' --include='*.jsx' --include='*.ts' --include='*.tsx' \
	--include='*.vue' --include='*.svelte' \
	"$_mb_root" 2>/dev/null)
EOF

	[ "$_mb_any" = 1 ] || return 3
}
