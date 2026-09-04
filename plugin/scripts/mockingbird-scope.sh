#!/usr/bin/env bash
# The deterministic core of /design-verify. Everything here is plain bash
# working on the manifest's flat TSV normal form (mockingbird-manifestlib.sh)
# or on git/grep output — no LLM involved, no judgement calls. What needs
# judgement (does this label match this data source) is deliberately NOT
# here: it lives in the reviewer dispatches, and its output is fed back into
# this script's --check-seam and --coverage modes, which ARE deterministic.
#
# Usage: mockingbird-scope.sh <mode> --root DIR [mode-specific args]
#
# Modes:
#   --validate                     manifest schema + semantic validation
#   --elements [--screen ID]       flat element TSV (the coverage denominator)
#   --locate ELEMENT_ID            adapter locator candidates, tier-ranked
#   --scope [--since REF]          screens touched by uncommitted/recent changes
#   --tokens                       raw values in stylesheets (css/sass/scss/less) and
#                                  inline style attributes, outside token-definition files;
#                                  output file:line:<token|ambiguous:a|b|->:content — the
#                                  token column is what fix-policy's "exactly one" rule reads
#   --check-seam FILE              apply the four anti-hallucination rules to
#                                   an MB-SEAM block, downgrading as required
#   --seam-to-coverage FILE --stage semantic|flow
#                                  turn a checked MB-SEAM block into MB-COVERAGE lines
#   --coverage FILE [--screen ID]  MB-COVERAGE bookkeeping + verdict (denominator: one screen if given)
#   --fix-scope                    adapter globs, as an editor allowlist
#   --healthcheck                  commands that prove the code still RUNS
#                                  ("workdir<TAB>command"); named, never run here
#   --self-test                    built-in assertions, no LLM, no fixtures
#
# Exit codes (mode-specific; --self-test is 0/1 pass-fail only):
#   0 ok · 1 --coverage only: MISMATCH · 2 usage error · 3 nothing in scope /
#   no candidate · 4 manifest invalid · 5 manifest outside the parser subset
set -u
# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PLUGIN_ROOT="$(dirname -- "$HERE")"
. "$PLUGIN_ROOT/lib/mockingbird-manifestlib.sh"
. "$PLUGIN_ROOT/lib/mockingbird-coveragelib.sh"

usage() {
	echo "usage: mockingbird-scope.sh <mode> --root DIR [args]" >&2
	echo "modes: --validate --elements --locate ID --scope --tokens --check-seam FILE --seam-to-coverage FILE --stage S --coverage FILE --fix-scope --healthcheck --self-test" >&2
	exit 2
}

[ $# -ge 1 ] || usage
MODE="$1"; shift

ROOT="" SCREEN="" ELEMENT="" SINCE="" SEAM_FILE="" COVERAGE_FILE="" ADAPTER="" STAGE=""
while [ $# -gt 0 ]; do
	case "$1" in
		--root) ROOT="$2"; shift 2 ;;
		--screen) SCREEN="$2"; shift 2 ;;
		--since) SINCE="$2"; shift 2 ;;
		--adapter) ADAPTER="$2"; shift 2 ;;
		--stage) STAGE="$2"; shift 2 ;;
		*)
			case "$MODE" in
				--locate) [ -z "$ELEMENT" ] && { ELEMENT="$1"; shift; continue; } ;;
				--check-seam|--seam-to-coverage) [ -z "$SEAM_FILE" ] && { SEAM_FILE="$1"; shift; continue; } ;;
				--coverage) [ -z "$COVERAGE_FILE" ] && { COVERAGE_FILE="$1"; shift; continue; } ;;
			esac
			usage
			;;
	esac
done

[ "$MODE" = "--self-test" ] || [ "$MODE" = "--seam-to-coverage" ] || { [ -n "$ROOT" ] || usage; }

MANIFEST="${ROOT:-}/docs/design/manifest.yaml"

_meta() { mb_manifest_meta "$MANIFEST" | awk -F'\t' -v k="$1" '$1==k{print $2; exit}'; }

_load_adapter() {
	local name="$1"
	local f="$PLUGIN_ROOT/scripts/adapters/$name.sh"
	[ -f "$f" ] || { echo "unknown adapter: $name" >&2; exit 2; }
	unset -f mb_adapter_globs mb_adapter_locate mb_adapter_capabilities mb_adapter_token_sources 2>/dev/null
	# shellcheck disable=SC1090
	. "$f"
}

_resolve_adapter() {
	[ -n "$ADAPTER" ] && { printf '%s' "$ADAPTER"; return; }
	local a
	a="$(_meta primary_adapter)"
	printf '%s' "${a:-web}"
}

case "$MODE" in

	--validate)
		[ -f "$MANIFEST" ] || { echo "no manifest at $MANIFEST" >&2; exit 3; }
		ERR="$(MB_VALIDATE_ROOT="$ROOT" mb_manifest_validate "$MANIFEST" 2>&1 1>/dev/null)"
		RC=$?
		[ -n "$ERR" ] && printf '%s\n' "$ERR" >&2
		case "$RC" in
			0) echo "valid" ;;
			5) exit 5 ;;
			6) exit 4 ;;
			*) exit "$RC" ;;
		esac
		;;

	--elements)
		[ -f "$MANIFEST" ] || exit 3
		TSV="$(mb_manifest_to_tsv "$MANIFEST")" || exit $?
		if [ -n "$SCREEN" ]; then
			printf '%s\n' "$TSV" | awk -F'\t' -v s="$SCREEN" '$1==s'
		else
			printf '%s\n' "$TSV"
		fi
		;;

	--locate)
		[ -n "$ELEMENT" ] || usage
		[ -f "$MANIFEST" ] || exit 3
		TSV="$(mb_manifest_to_tsv "$MANIFEST")" || exit $?
		ROW="$(printf '%s\n' "$TSV" | awk -F'\t' -v id="$ELEMENT" '$4==id{print; exit}')"
		[ -n "$ROW" ] || { echo "no such element: $ELEMENT" >&2; exit 3; }
		LABEL="$(mb_tsv_field "$ROW" "$MB_F_ELEMENT_LABEL")"
		[ "$LABEL" = "-" ] && LABEL=""
		_load_adapter "$(_resolve_adapter)"
		SR="$(_meta source_roots | cut -d, -f1)"
		if [ -n "$SR" ] && [ -d "$ROOT/$SR" ]; then
			MB_ADAPTER_ROOT="$ROOT/$SR" mb_adapter_locate "$ELEMENT" "$LABEL" | sed "s|\t|\t$SR/|"
		else
			MB_ADAPTER_ROOT="$ROOT" mb_adapter_locate "$ELEMENT" "$LABEL"
		fi
		;;

	--scope)
		# Narrows by DESIGN-side changes only (which artboard or the manifest
		# itself changed) -- attributing an arbitrary implementation-file
		# change back to a specific screen would need the same expensive
		# locate work /design-verify itself does, so --scope does not attempt
		# it. Without git, or without anything to narrow by, every screen is
		# in scope: silent under-scoping would be worse than over-scoping.
		[ -d "$ROOT" ] || exit 3
		[ -f "$MANIFEST" ] || exit 3
		TSV="$(mb_manifest_to_tsv "$MANIFEST")" || exit $?
		ALL_SCREENS="$(printf '%s\n' "$TSV" | cut -f"$MB_F_SCREEN_ID" | sort -u)"

		if ! git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
			echo "$ALL_SCREENS"
		else
			if [ -n "$SINCE" ]; then
				CHANGED="$(git -C "$ROOT" diff --name-only "$SINCE" -- docs/design 2>/dev/null)"
			else
				CHANGED="$( { git -C "$ROOT" diff --name-only -- docs/design; \
				              git -C "$ROOT" diff --name-only --cached -- docs/design; \
				              git -C "$ROOT" ls-files --others --exclude-standard -- docs/design; } 2>/dev/null | sort -u)"
			fi
			if [ -z "$CHANGED" ] || printf '%s\n' "$CHANGED" | grep -qF 'docs/design/manifest.yaml'; then
				echo "$ALL_SCREENS"
			else
				printf '%s\n' "$TSV" | awk -F'\t' -v changed="$CHANGED" '
					BEGIN { n = split(changed, arr, "\n"); for (i = 1; i <= n; i++) touched[arr[i]] = 1 }
					touched[$3] { print $1 }
				' | sort -u
			fi
		fi
		;;

	--tokens)
		[ -f "$MANIFEST" ] || exit 3
		_load_adapter "$(_resolve_adapter)"
		SRC="$(mb_adapter_token_sources)"
		[ -n "$SRC" ] || exit 0
		# Files that DEFINE tokens are the one place raw values belong: the
		# manifest's tokens_css, anything listed under token_definitions:, and
		# the usual naming convention for such files.
		EXCL="$ROOT/$(_meta tokens_css)"$'\n'
		for d in $(_meta token_definitions | tr ',' ' '); do EXCL="$EXCL$ROOT/$d"$'\n'; done
		# source_roots: [client/src] restricts every scan to the code this
		# manifest describes; a monorepo's other apps are not in scope.
		ROOTS="$(_meta source_roots | tr ',' ' ')"; [ -n "$ROOTS" ] || ROOTS="."
		SCAN=""; for r in $ROOTS; do SCAN="$SCAN $ROOT/$r"; done
		# Every custom property the project actually defines -- in the token
		# definition files (which sit outside source_roots and would otherwise
		# be missed), as a CSS declaration anywhere in the scanned code, or
		# through setProperty() from JS (themes are applied that way). A var(--x, raw) whose --x is in this list is a
		# token with a fallback that never renders, and stays unflagged. One
		# whose --x is NOT defined anywhere is not a fallback at all: the raw
		# value is what the browser paints, every time. Outpost had four such
		# lines behind --error-color, --border-color and --hover-color, none
		# of which exists.
		# shellcheck disable=SC2086  # SCAN is a deliberate word list
		DEFINED="|$(
			{ printf '%s' "$EXCL" | while IFS= read -r tf; do [ -f "$tf" ] && grep -hoE -- '--[A-Za-z0-9_-]+[ \t]*:' "$tf" 2>/dev/null | sed -E 's/[ \t]*:$//'; done
			  grep -rhoE -- '--[A-Za-z0-9_-]+[ \t]*:' $SCAN --include=*.css --include=*.sass --include=*.scss --include=*.less 2>/dev/null | sed -E 's/[ \t]*:$//'
			  grep -rhoE -- "setProperty\([\"']--[A-Za-z0-9_-]+" $SCAN --include=*.js --include=*.jsx --include=*.ts --include=*.tsx 2>/dev/null | sed -E "s/.*[\"'](--)/\1/"
			} | sort -u | tr '\n' '|'
		)"
		# Token map: hex value -> defining token name(s), built from the same
		# definition files that are excluded from scanning. This is what makes
		# a finding fixable: fix-policy.md allows an automatic replacement only
		# when exactly ONE token has exactly this value. Two tokens sharing a
		# value (dark theme: --white and --text are both #FFFFFF) is
		# "ambiguous" and stays a report.
		TOKMAP="$(printf '%s' "$EXCL" | while IFS= read -r tf; do [ -f "$tf" ] && cat "$tf"; done | awk '
			{
				# every "--name: #hex" / "$name: #hex" on the line, not just one at
				# the start: a minified or one-line :root{...} block is common
				rest = $0
				# Functional notations first: --gray: rgba(255,255,255,.1) is how
				# a themed grey scale is usually written, and without this the
				# map cannot name the token for such a finding, and the
				# exactly-one-token rule in fix-policy never fires on it.
				fnrest = $0
				while (match(fnrest, /(--|\$)[A-Za-z0-9_-]+[ \t]*:[ \t]*(rgba?|hsla?)\([0-9][^)]*\)/)) {
					fline = substr(fnrest, RSTART, RLENGTH); fnrest = substr(fnrest, RSTART + RLENGTH)
					fname = fline; sub(/[ \t]*:.*$/, "", fname)
					fval = fline; sub(/^[^:]*:[ \t]*/, "", fval)
					gsub(/[ \t]/, "", fval); fval = tolower(fval)
					if (index(seen[fval], "|" fname "|") == 0) { seen[fval] = seen[fval] "|" fname "|"; names[fval] = (names[fval] == "" ? fname : names[fval] "|" fname) }
				}
				while (match(rest, /(--|\$)[A-Za-z0-9_-]+[ \t]*:[ \t]*#[0-9a-fA-F]{3,8}/)) {
					line = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
					name = line; sub(/[ \t]*:.*$/, "", name)
					hex = line; sub(/^.*#/, "#", hex); hex = tolower(hex)
					if (length(hex) == 4) hex = "#" substr(hex,2,1) substr(hex,2,1) substr(hex,3,1) substr(hex,3,1) substr(hex,4,1) substr(hex,4,1)
					if (index(seen[hex], "|" name "|") == 0) { seen[hex] = seen[hex] "|" name "|"; names[hex] = (names[hex] == "" ? name : names[hex] "|" name) }
				}
			}
			END { for (h in names) print h "\t" names[h] }')"
		# Font tokens: "--name: <family list>" whose value ends in a generic family
		# and carries no size (a family token, not a `font` shorthand -- replacing
		# font-family: monospace with a shorthand would change size and weight).
		FONTMAP="$(printf '%s' "$EXCL" | while IFS= read -r tf; do [ -f "$tf" ] && cat "$tf"; done | awk '
			{ rest = $0
			  while (match(rest, /(--|\$)[A-Za-z0-9_-]+[ \t]*:[ \t]*[^;{}]*(monospace|sans-serif|serif|system-ui)[ \t]*;?/)) {
				line = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
				if (line ~ /[0-9](px|rem|em|%)/) continue      # shorthand with a size: not a family token
				name = line; sub(/[ \t]*:.*$/, "", name)
				gen = (line ~ /monospace/) ? "monospace" : (line ~ /sans-serif|system-ui/) ? "sans-serif" : "serif"
				if (index(seen[gen], "|" name "|") == 0) { seen[gen] = seen[gen] "|" name "|"; names[gen] = (names[gen] == "" ? name : names[gen] "|" name) }
			  } }
			END { for (g in names) print g "\t" names[g] }')"
		token_for() { # token_for <content> -> token | ambiguous:a|b | -
			local hex
			case "$1" in
				*font-family*)
					local gen="" fams
					case "$1" in *monospace*|*"font-family: mono"*|*"font-family:mono"*) gen=monospace ;; *sans-serif*|*system-ui*) gen=sans-serif ;; *serif*) gen=serif ;; esac
					[ -n "$gen" ] || { printf -- '-'; return; }
					fams="$(printf '%s\n' "$FONTMAP" | awk -F'\t' -v g="$gen" '$1==g{print $2; exit}')"
					case "$fams" in "") printf -- '-' ;; *"|"*) printf 'ambiguous:%s' "$fams" ;; *) printf '%s' "$fams" ;; esac
					return ;;
			esac
			local fn
			fn="$(printf '%s' "$1" | grep -oE '(rgba?|hsla?)\([0-9][^)]*\)' | head -1 | tr -d ' \t' | tr 'A-Z' 'a-z')"
			if [ -n "$fn" ]; then
				local fnames
				fnames="$(printf '%s\n' "$TOKMAP" | awk -F'\t' -v v="$fn" '$1==v{print $2; exit}')"
				case "$fnames" in "") printf -- '-' ;; *"|"*) printf 'ambiguous:%s' "$fnames" ;; *) printf '%s' "$fnames" ;; esac
				return
			fi
			hex="$(printf '%s' "$1" | grep -oE '#[0-9a-fA-F]{3,8}\b' | head -1 | tr 'A-Z' 'a-z')"
			[ -n "$hex" ] || { printf -- '-'; return; }
			[ "${#hex}" -eq 4 ] && hex="#${hex:1:1}${hex:1:1}${hex:2:1}${hex:2:1}${hex:3:1}${hex:3:1}"
			local names
			names="$(printf '%s\n' "$TOKMAP" | awk -F'\t' -v h="$hex" '$1==h{print $2; exit}')"
			case "$names" in "") printf -- '-' ;; *"|"*) printf 'ambiguous:%s' "$names" ;; *) printf '%s' "$names" ;; esac
		}
		printf '%s\n' "$SRC" | while IFS=$'\t' read -r glob re; do
			[ -n "$glob" ] || continue
			name="${glob##*/}"
			# shellcheck disable=SC2086  # SCAN is a deliberate word list of directories
			find $SCAN \( -path '*/node_modules/*' -o -path '*/dist/*' -o -path '*/build/*' -o -path '*/.git/*' \) -prune -o -type f -name "$name" -print 2>/dev/null \
			| sed 's|/\./|/|' | while IFS= read -r f; do
				case "$EXCL" in *"$f"$'\n'*) continue ;; esac
				case "$(basename "$f")" in _colors.*|_tokens.*|_variables.*|tokens.css|_theme.*) continue ;; esac
				grep -q '@font-face' "$f" 2>/dev/null && continue   # a file that defines fonts is a definition file
				# A raw value inside var(--x, raw) is a token WITH a fallback, not a
				# raw value -- it was 40% of the noise on Outpost. Strip such
				# fallbacks before matching, but ONLY when --x is really defined
				# somewhere. If it is not, the fallback is the effective value and
				# hiding it would be a silent pass.
				awk -v defs="$DEFINED" '{
					out = ""; rest = $0
					while (match(rest, /var\(--[A-Za-z0-9_-]+,[^)]*\)/)) {
						pre = substr(rest, 1, RSTART - 1)
						m = substr(rest, RSTART, RLENGTH)
						rest = substr(rest, RSTART + RLENGTH)
						nm = m; sub(/^var\(/, "", nm); sub(/,.*$/, "", nm)
						if (index(defs, "|" nm "|") > 0) m = "var(--_)"
						out = out pre m
					}
					print out rest
				}' "$f" 2>/dev/null | grep -nE -- "$re" | grep -vE 'font-family[[:space:]]*:[[:space:]]*(inherit|initial|unset|var\()' | while IFS=: read -r ln content; do
					printf '%s:%s:%s:%s\n' "${f#"$ROOT"/}" "$ln" "$(token_for "$content")" "$(printf '%s' "$content" | sed 's/^[[:space:]]*//')"
				done
			done
		done
		;;

	--fix-scope)
		# The editor's allowlist is the union of two spaces, not just the
		# locator's: element fixes live in components, token fixes live in
		# stylesheets. Giving mb_adapter_globs both roles blocked every token
		# fix (found on Outpost: 16 findings, all in .sass, none allowed).
		# Lines starting with "!" are exclusions -- the files that DEFINE
		# tokens are never editable, they are the source of truth.
		[ -f "$MANIFEST" ] || { echo "no manifest at $MANIFEST" >&2; exit 3; }
		_load_adapter "$(_resolve_adapter)"
		{
			mb_adapter_globs
			mb_adapter_token_sources | cut -f1
		} | awk 'NF && !seen[$0]++'
		TC="$(_meta tokens_css)"; [ -n "$TC" ] && printf '!%s\n' "$TC"
		for d in $(_meta token_definitions | tr ',' ' '); do [ -n "$d" ] && printf '!%s\n' "$d"; done
		;;
	--healthcheck)
		# All five review stages read code as text; none of them notices a
		# ReferenceError. mockingbird writes code itself (fix path, editor
		# agent), so "does it still run" belongs in the deterministic core --
		# see the header comment on web.sh's mb_adapter_healthcheck. Output is
		# advisory input for the caller, which decides whether to run it: exit
		# 3 when the project offers no such command, so "nothing to run" stays
		# distinguishable from "everything passed".
		[ -f "$MANIFEST" ] || { echo "no manifest at $MANIFEST" >&2; exit 3; }
		_load_adapter "$(_resolve_adapter)"
		HC="$(mb_adapter_healthcheck "$ROOT" 2>/dev/null)"
		# Narrow to the packages the manifest actually points at. A monorepo
		# answers with every workspace it has (Outpost: landing, connector,
		# client) and linting the ones no screen lives in is pure wall-clock.
		# The repo-root entry is kept only when nothing more specific matched,
		# so a single-package project still gets its command.
		SR="$(_meta source_roots | tr ',' ' ')"
		if [ -n "$SR" ] && [ -n "$HC" ]; then
			NARROW="" ROOTONLY="" KINDS=""
			while IFS="$(printf '\t')" read -r wd cmd scope; do
				[ -n "$wd" ] || continue
				[ "$wd" = "." ] && continue
				for r in $SR; do
					case "${r%/}/" in
						"${wd%/}/"*)
							NARROW="${NARROW}${wd}$(printf '\t')${cmd}$(printf '\t')${scope}
"
							KINDS="$KINDS ${cmd##* }" ;;
					esac
				done
			done <<EOF
$HC
EOF
			# What the repo root keeps:
			#
			#  - every "files" command, ALONGSIDE the packages' own. Which paths
			#    a linter actually covers is decided by its config, not by this
			#    script: Outpost's root config matches server/ and scripts/ only
			#    and reports a client file as "ignored", while the client config
			#    covers the client. Keeping only one of them silently stops
			#    linting half the repo -- which is exactly what happened when
			#    this code preferred the root. Running both costs one extra pass
			#    and covers everything.
			#  - a "whole" command only for a kind no narrowed package offers. A
			#    monorepo often keeps the entire test suite at the top (Outpost:
			#    1086 tests behind the root "test" script, invisible to a
			#    client-only scan).
			if [ -n "$NARROW" ]; then
				ROOTFILES=""
				while IFS="$(printf '\t')" read -r wd cmd scope; do
					[ "$wd" = "." ] || continue
					if [ "$scope" = "files" ]; then
						ROOTFILES="${ROOTFILES}${wd}$(printf '\t')${cmd}$(printf '\t')${scope}
"
						continue
					fi
					case " $KINDS " in *" ${cmd##* } "*) continue ;; esac
					ROOTONLY="${ROOTONLY}${wd}$(printf '\t')${cmd}$(printf '\t')${scope}
"
				done <<EOF
$HC
EOF
				HC="${ROOTFILES}${NARROW}${ROOTONLY}"
				HC="${HC%$'\n'}"
			fi
		fi
		[ -n "$HC" ] || exit 3
		printf '%s\n' "$HC"
		;;

	--check-seam)
		[ -n "$SEAM_FILE" ] || usage
		mb_check_seam "$SEAM_FILE" "$ROOT"
		;;

	--seam-to-coverage)
		[ -n "$SEAM_FILE" ] && [ -n "$STAGE" ] || usage
		mb_seam_to_coverage "$SEAM_FILE" "$STAGE"
		;;

	--coverage)
		[ -n "$COVERAGE_FILE" ] || usage
		[ -f "$MANIFEST" ] || exit 3
		mb_manifest_coverage "$COVERAGE_FILE" "$MANIFEST" "$ROOT" "$SCREEN"
		;;

	--self-test)
		exec "$HERE/mockingbird-scope-selftest.sh"
		;;

	*)
		usage
		;;
esac
