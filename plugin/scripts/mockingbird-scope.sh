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
#   --tokens                       raw values outside the token file
#   --check-seam FILE              apply the four anti-hallucination rules to
#                                   an MB-SEAM block, downgrading as required
#   --seam-to-coverage FILE --stage semantic|flow
#                                  turn a checked MB-SEAM block into MB-COVERAGE lines
#   --coverage FILE                MB-COVERAGE bookkeeping + verdict
#   --fix-scope                    adapter globs, as an editor allowlist
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
	echo "modes: --validate --elements --locate ID --scope --tokens --check-seam FILE --seam-to-coverage FILE --stage S --coverage FILE --fix-scope --self-test" >&2
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
		MB_ADAPTER_ROOT="$ROOT" mb_adapter_locate "$ELEMENT" "$LABEL"
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
		SRC_LINE="$(mb_adapter_token_sources)"
		[ -n "$SRC_LINE" ] || exit 0
		RAW_RE="${SRC_LINE#*$'\t'}"
		TOKENS_CSS="$ROOT/$(_meta tokens_css)"
		while IFS= read -r f; do
			[ -n "$f" ] || continue
			case "$f" in "$TOKENS_CSS") continue ;; esac
			grep -nE -- "$RAW_RE" "$f" 2>/dev/null | while IFS=: read -r ln content; do
				printf '%s:%s:%s\n' "${f#"$ROOT"/}" "$ln" "$(printf '%s' "$content" | sed 's/^[[:space:]]*//')"
			done
		done < <(find "$ROOT" -path '*/node_modules/*' -prune -o -type f -name '*.css' -print 2>/dev/null)
		;;

	--fix-scope)
		_load_adapter "$(_resolve_adapter)"
		mb_adapter_globs
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
		mb_manifest_coverage "$COVERAGE_FILE" "$MANIFEST" "$ROOT"
		;;

	--self-test)
		exec "$HERE/mockingbird-scope-selftest.sh"
		;;

	*)
		usage
		;;
esac
