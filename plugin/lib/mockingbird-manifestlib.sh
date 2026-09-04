# shellcheck shell=bash disable=SC2034
# Reads and validates docs/design/manifest.yaml. Sourced by scripts/ and by
# tests. NEVER sourced by the hook (plugin/hooks/) — the hook stays free of
# domain knowledge and must not depend on yq or on this file's parser.
#
# mb_manifest_to_tsv normalizes the manifest to a flat TSV: one line per
# element, 18 tab-separated fields (see mockingbird-manifest.awk header).
# Every downstream check (--elements, --locate, --validate, coverage) reads
# only this TSV, never the YAML directly, so a test can assert against the
# normal form without needing yq.
#
# Two parsing paths:
#   - yq present: shell out to it and flatten with jq. Broader YAML support.
#   - yq absent (the common case: yq ships nowhere by default): the strict
#     line-based awk parser in mockingbird-manifest.awk, which understands
#     exactly the subset documented in manifest-schema.md and REFUSES (exit 5)
#     on anything else rather than guessing. A parser that silently mis-reads
#     a manifest would poison every check built on top of it.
# NOTE: the yq path is implemented defensively but not exercised by this
# plugin's own test suite, because no development machine here has yq
# installed. Treat it as unverified until it has run once for real.

# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
MB_LIB_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MB_MANIFEST_AWK="$MB_LIB_DIR/mockingbird-manifest.awk"

# TSV field indices, 1-based, for readable `cut -f` / awk '$N' callers.
# shellcheck disable=SC2034
MB_F_SCREEN_ID=1
MB_F_SCREEN_KIND=2
MB_F_SCREEN_ARTBOARD=3
MB_F_ELEMENT_ID=4
MB_F_ELEMENT_TYPE=5
MB_F_ELEMENT_LABEL=6
MB_F_ELEMENT_STATUS=7
MB_F_ELEMENT_VERIFY=8
MB_F_ELEMENT_DATA_SOURCE=9
MB_F_SEMANTIC_MEANS=10
MB_F_SEMANTIC_CONCEPT=11
MB_F_SEMANTIC_ALIASES=12
MB_F_SEMANTIC_NOT=13
MB_F_STATES=14
MB_F_LOCATOR_WEB=15
MB_F_DEFERRED_REASON=16
MB_F_SKIP_REASON=17
MB_F_SCREEN_USES=18

# Emit the normalized element TSV for <file> on stdout.
# Exit: 0 ok · 3 file missing/unreadable · 5 parse error (yq path: yq/jq failure).
mb_manifest_to_tsv() {
	local file="$1"
	[ -f "$file" ] && [ -r "$file" ] || return 3
	if command -v yq >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
		yq -o=json '.' -- "$file" 2>/dev/null | jq -r '
			(.screens // [])[] as $s
			| (($s.elements // [])[]) as $e
			| [
				($s.id // "-"), ($s.kind // "-"), ($s.artboard // "-"),
				($e.id // "-"), ($e.type // "-"), ($e.label // "-"),
				($e.status // "-"), ($e.verify // "-"), ($e.data_source // "-"),
				($e.semantic_anchor.means // "-"), ($e.semantic_anchor.concept // "-"),
				(if ($e.semantic_anchor.aliases // []) == [] then "-" else ($e.semantic_anchor.aliases | join(",")) end),
				(if ($e.semantic_anchor.not // []) == [] then "-" else ($e.semantic_anchor.not | join(",")) end),
				(if ($e.states // []) == [] then "-" else (($e.states // []) | map(.id) | join(",")) end),
				($e.locators.web // "-"),
				($e.deferred_reason // "-"), ($e.reason // "-"),
				(if ($s.uses // []) == [] then "-" else ($s.uses | join(",")) end)
			] | @tsv'
		return $?
	fi
	awk -f "$MB_MANIFEST_AWK" -- "$file"
}

# Emit top-level scalar metadata ("key\tvalue" per line): schema, project,
# revision, updated, design_system, mockups_index, tokens_css, primary_adapter.
# Same exit contract as mb_manifest_to_tsv.
mb_manifest_meta() {
	local file="$1"
	[ -f "$file" ] && [ -r "$file" ] || return 3
	if command -v yq >/dev/null 2>&1; then
		yq -r '
			to_entries[]
			| select(.key as $k | ["schema","project","revision","updated","design_system","mockups_index","tokens_css","primary_adapter","token_definitions","source_roots"] | index($k))
			| "\(.key)\t\(if (.value|type)=="array" then (.value|join(",")) else .value end)"
		' -- "$file" 2>/dev/null
		return $?
	fi
	MB_META_FD=/dev/fd/3 awk -f "$MB_MANIFEST_AWK" -- "$file" 3>&1 1>/dev/null
}

# Field getter: mb_tsv_field <tsv-line> <field-index>
mb_tsv_field() {
	printf '%s' "$1" | cut -f "$2"
}

# Return 0 if <id> matches the manifest ID grammar (screen or element id).
mb_valid_id() {
	[[ "$1" =~ ^UI-[A-Z0-9]+(-[A-Z0-9]+){0,3}$ ]] || return 1
	[ "${#1}" -le 40 ]
}

# Validate a manifest end to end: parses it, then checks the semantic rules
# documented in manifest-schema.md. Prints one problem per line to stderr.
# Exit: 0 valid · 3 file missing · 5 parse error (subset violated) ·
#       6 well-formed but semantically invalid (see stderr for which rule).
mb_manifest_validate() {
	local file="$1" tsv rc problems=0
	tsv="$(mb_manifest_to_tsv "$file")"; rc=$?
	[ "$rc" -eq 0 ] || return "$rc"

	[ -n "$tsv" ] || { echo "manifest has no elements" >&2; return 6; }

	local seen_screens=' ' seen_elements=' '
	while IFS=$'\t' read -r scr_id scr_kind scr_artboard elem_id elem_type elem_label \
		elem_status elem_verify elem_ds sa_means sa_concept sa_aliases sa_not \
		states loc_web reason_deferred reason_skip scr_uses; do
		[ -n "$elem_id" ] || continue

		if ! mb_valid_id "$scr_id"; then
			echo "invalid screen id grammar: $scr_id" >&2; problems=$((problems + 1))
		fi
		if ! mb_valid_id "$elem_id"; then
			echo "invalid element id grammar: $elem_id" >&2; problems=$((problems + 1))
		fi
		case "$seen_screens" in
			*" $scr_id "*) ;;
			*) seen_screens="$seen_screens$scr_id " ;;
		esac
		case "$seen_elements" in
			*" $elem_id "*) echo "duplicate element id: $elem_id" >&2; problems=$((problems + 1)) ;;
			*) seen_elements="$seen_elements$elem_id " ;;
		esac

		case "$elem_status" in
			required|recommended) ;;
			deferred)
				[ "$reason_deferred" != "-" ] || { echo "$elem_id: status deferred without deferred_reason" >&2; problems=$((problems + 1)); } ;;
			*) echo "$elem_id: invalid status '$elem_status'" >&2; problems=$((problems + 1)) ;;
		esac
		case "$elem_verify" in
			required|recommended) ;;
			skip)
				[ "$reason_skip" != "-" ] || { echo "$elem_id: verify skip without reason" >&2; problems=$((problems + 1)); } ;;
			*) echo "$elem_id: invalid verify '$elem_verify'" >&2; problems=$((problems + 1)) ;;
		esac

		if [ "$elem_ds" != "static" ] && [ "$elem_ds" != "-" ]; then
			[ "$sa_means" != "-" ] || { echo "$elem_id: data-bearing element without semantic_anchor.means" >&2; problems=$((problems + 1)); }
		fi

		case ",$states," in
			*,default,*) ;;
			*) echo "$elem_id: states list has no 'default'" >&2; problems=$((problems + 1)) ;;
		esac

		if [ "$scr_artboard" != "-" ] && [ -n "${MB_VALIDATE_ROOT:-}" ]; then
			[ -f "$MB_VALIDATE_ROOT/$scr_artboard" ] || { echo "$scr_id: artboard path does not exist: $scr_artboard" >&2; problems=$((problems + 1)); }
		fi
	done <<< "$tsv"

	# Cross-references: every id named in a screen's uses: list and in
	# allocations: owns/consumes must exist. A dangling reference here would
	# otherwise surface much later as a confusing "element not found" in
	# /design-verify or a silently empty consumed-elements list in the spec.
	local all_ids ref
	all_ids=" $(printf '%s\n' "$tsv" | awk -F'\t' '{print $1; print $4}' | sort -u | tr '\n' ' ') "
	while IFS=$'\t' read -r _s1 _s2 _s3 _e1 _e2 _e3 _e4 _e5 _e6 _e7 _e8 _e9 _e10 _e11 _e12 _e13 _e14 uses; do
		[ -n "$uses" ] && [ "$uses" != "-" ] || continue
		for ref in ${uses//,/ }; do
			case "$all_ids" in *" $ref "*) ;; *) echo "$_s1: uses references unknown id $ref" >&2; problems=$((problems + 1)) ;; esac
		done
	done <<< "$(printf '%s\n' "$tsv" | sort -u -t"$(printf '\t')" -k1,1)"
	while IFS=$'\t' read -r spec owns consumes; do
		[ -n "$spec" ] || continue
		for ref in ${owns//,/ } ${consumes//,/ }; do
			[ "$ref" != "-" ] || continue
			case "$all_ids" in *" $ref "*) ;; *) echo "allocation $spec references unknown id $ref" >&2; problems=$((problems + 1)) ;; esac
		done
	done <<< "$(mb_manifest_allocations "$file")"

	if [ -n "${MB_VALIDATE_ROOT:-}" ]; then
		for d in $(mb_manifest_meta "$file" | awk -F'\t' '$1=="token_definitions"{print $2}' | tr ',' ' '); do
			[ -f "$MB_VALIDATE_ROOT/$d" ] || { echo "token_definitions: file does not exist: $d" >&2; problems=$((problems + 1)); }
		done
	fi

	[ "$problems" -eq 0 ] || return 6
	return 0
}

# Emit "spec\towns-csv\tconsumes-csv" per allocations: entry ("-" when empty).
# Empty output when the manifest has no allocations (the single-spec case).
mb_manifest_allocations() {
	local file="$1"
	[ -f "$file" ] && [ -r "$file" ] || return 3
	if command -v yq >/dev/null 2>&1; then
		yq -r '(.allocations // [])[] | [.spec, (if (.owns // []) == [] then "-" else (.owns|join(",")) end), (if (.consumes // []) == [] then "-" else (.consumes|join(",")) end)] | @tsv' -- "$file" 2>/dev/null
		return $?
	 fi
	MB_META_FD=/dev/fd/3 awk -f "$MB_MANIFEST_AWK" -- "$file" 3>&1 1>/dev/null | awk -F'\t' '$1=="allocation"{print $2 "\t" $3 "\t" $4}'
}
