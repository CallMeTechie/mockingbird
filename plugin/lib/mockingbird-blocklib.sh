# shellcheck shell=bash
# Domain helpers for the mockingbird design marker block: detection with fence
# filtering, the four-state exit contract, facts validation, and insertion.
# Sourced by the carrying-design-through skill's scripts and by the block tests.
# Never sourced by the hook — the hook stays free of domain knowledge.

MB_DESIGN_BEGIN='<!-- mockingbird:design:begin -->'
MB_DESIGN_END='<!-- mockingbird:design:end -->'
MB_SECURITY_BEGIN='<!-- preflight:security:begin -->'

MB_REQUIRED_FACT_KEYS='manifest design_rev design_hash system index adapter screens'
MB_OPTIONAL_FACT_KEYS='consumes shared'

# Line numbers where <file> contains the exact line <text>, one per line.
# A match inside a fenced code block or embedded in a sentence does NOT count:
# a spec that documents the block format is not a spec that has one. Without
# this, mockingbird's own spec (which shows the format as an example) would
# classify as damaged and every run would abort.
mb_fenced_line_matches() {
	awk -v want="$2" '
		{ line = $0; sub(/[[:space:]]+$/, "", line); sub(/^[[:space:]]+/, "", line) }
		line ~ /^(```|~~~)/ { fence = !fence; next }
		fence { next }
		line == want { print NR }
	' "$1" 2>/dev/null
}

# Same, but WITHOUT fence filtering. Only used to detect a block hidden by an
# unterminated fence; never to locate a block — a documented example would count.
mb_raw_line_matches() {
	awk -v want="$2" '
		{ line = $0; sub(/[[:space:]]+$/, "", line); sub(/^[[:space:]]+/, "", line) }
		line == want { print NR }
	' "$1" 2>/dev/null
}

# Return 0 if a code fence is still open at end of <file>.
mb_fence_open_at_eof() {
	awk '
		{ line = $0; sub(/[[:space:]]+$/, "", line); sub(/^[[:space:]]+/, "", line) }
		line ~ /^(```|~~~)/ { fence = !fence }
		END { exit fence ? 0 : 1 }
	' "$1" 2>/dev/null
}

# Classify the design block in <file>. No stdout; the exit code is the answer.
#   0 = exactly one begin and one end, begin before end -> may replace
#   1 = neither marker present                          -> may insert fresh
#   2 = anything else (one-sided, duplicated, reversed, or a real block hidden
#       by an unterminated fence)                        -> abort, block damaged
#   3 = file missing or unreadable                       -> abort, wrong path
# Always branch on all four codes. Never collapse 2 into 1 — inserting between
# damaged markers eats document content.
mb_design_block_state() {
	local file="$1" lb le nb ne rb re
	[ -f "$file" ] && [ -r "$file" ] || return 3
	lb="$(mb_fenced_line_matches "$file" "$MB_DESIGN_BEGIN")"
	le="$(mb_fenced_line_matches "$file" "$MB_DESIGN_END")"
	nb="$(printf '%s' "$lb" | grep -c . || :)"
	ne="$(printf '%s' "$le" | grep -c . || :)"
	if mb_fence_open_at_eof "$file"; then
		rb="$(mb_raw_line_matches "$file" "$MB_DESIGN_BEGIN" | grep -c . || :)"
		re="$(mb_raw_line_matches "$file" "$MB_DESIGN_END" | grep -c . || :)"
		if [ "$((rb + re))" -gt "$((nb + ne))" ]; then return 2; fi
	fi
	if [ "$nb" -eq 0 ] && [ "$ne" -eq 0 ]; then return 1; fi
	if [ "$nb" -ne 1 ] || [ "$ne" -ne 1 ]; then return 2; fi
	[ "$(printf '%s' "$lb" | head -1)" -lt "$(printf '%s' "$le" | head -1)" ] || return 2
	return 0
}

# The "<!-- design: ... -->" facts token string from the block in <file>, or
# exit 1. Only the comment BETWEEN the markers counts — a prose mention above
# the block is an example, not the state. Whitespace is squeezed to single
# spaces so a wrapped continuation line is legal.
mb_design_facts_raw() {
	local file="$1" lb le
	lb="$(mb_fenced_line_matches "$file" "$MB_DESIGN_BEGIN" | head -1)"
	le="$(mb_fenced_line_matches "$file" "$MB_DESIGN_END" | head -1)"
	[ -n "$lb" ] && [ -n "$le" ] && [ "$lb" -lt "$le" ] || return 1
	sed -n "${lb},${le}p" "$file" \
	  | awk '/<!-- design:/{f=1} f{print} f && /-->/{exit}' \
	  | sed -e 's/.*<!-- design://' -e 's/-->.*//' | tr '\n' ' ' \
	  | tr -s '[:space:]' ' '
}

# Look up one key in a whitespace separated list of key=value tokens.
# Splitting-free on purpose: a value holding * or ? would otherwise be glob-
# expanded against the working directory.
mb_fact_get() {
	local rest=" $1 " val
	case "$rest" in
		*" $2="*) rest="${rest#*" $2="}"; val="${rest%%[[:space:]]*}"
		          printf '%s' "$val"; return 0 ;;
	esac
	return 1
}

# Return 0 if every item in a comma separated list matches the manifest ID
# grammar (screens/consumes/shared reference manifest element or screen IDs).
mb_valid_ui_id_list() {
	local list="$1" item
	[ -n "$list" ] || return 1
	IFS=',' read -r -a _mb_ids <<< "$list"
	[ "${#_mb_ids[@]}" -gt 0 ] || return 1
	for item in "${_mb_ids[@]}"; do
		[[ "$item" =~ ^UI-[A-Z0-9]+(-[A-Z0-9]+){0,3}$ ]] || return 1
		[ "${#item}" -le 40 ] || return 1
	done
	return 0
}

# Return 0 if the facts comment inside the design block carries every required
# key, no unknown or duplicate keys, and every value is well formed. Never
# guesses, never fills in a default: a silently completed fact hides a broken
# reference from everyone downstream.
mb_design_facts_valid() {
	local file="$1" raw tok k v seen=' '
	raw="$(mb_design_facts_raw "$file")" || return 1
	case "$raw" in *[![:space:]]*) ;; *) return 1 ;; esac
	# Reject glob metacharacters before any word splitting, so validation can
	# never depend on the working directory's contents.
	case "$raw" in *[*?[]*) return 1 ;; esac

	# shellcheck disable=SC2086  # deliberate word splitting on a sanitized string
	set -- $raw
	[ "$#" -ge 1 ] || return 1

	for tok in "$@"; do
		case "$tok" in *=*) ;; *) return 1 ;; esac
		k="${tok%%=*}"; v="${tok#*=}"
		case " $MB_REQUIRED_FACT_KEYS $MB_OPTIONAL_FACT_KEYS " in
			*" $k "*) ;;
			*) return 1 ;;
		esac
		case "$seen" in *" $k "*) return 1 ;; esac
		seen="$seen$k "
		[ -n "$v" ] || return 1
		case "$k" in
			design_rev)
				case "$v" in ''|*[!0-9]*) return 1 ;; esac ;;
			design_hash)
				[[ "$v" =~ ^sha256:[0-9a-f]{64}$ ]] || return 1 ;;
			adapter)
				# shellcheck disable=SC2194  # constant haystack, variable needle is intentional
				case " web tui desktop mobile " in *" $v "*) ;; *) return 1 ;; esac ;;
			screens|consumes|shared)
				mb_valid_ui_id_list "$v" || return 1 ;;
		esac
	done

	for k in $MB_REQUIRED_FACT_KEYS; do
		case "$seen" in *" $k "*) ;; *) return 1 ;; esac
	done
	return 0
}

# Insert or replace the design block in <file> using the rendered block text in
# <blockfile> (markers, facts comment, table — the whole region verbatim).
#
# The block is placed ABOVE preflight's security block, never inside it — this
# plugin's own spec documents that exact format, so the case is not
# hypothetical. There is no code dependency on preflight: the marker string is
# a text convention, and without preflight installed the security-block search
# simply never matches, and insertion falls through to EOF.
#
# Exit codes:
#   0 = written (block inserted or region replaced)
#   2 = existing block damaged -> refused, nothing written
#   3 = file missing -> refused, nothing written
#   4 = rendered block is byte-identical to what is already there -> no-op,
#       nothing written. This is what breaks the sync/nudge loop with preflight:
#       an idempotent sync produces no new hash, so no new nudge follows it.
mb_insert_block() {
	local file="$1" blockfile="$2" state tmp
	mb_design_block_state "$file"
	state=$?
	case "$state" in
		2|3) return "$state" ;;
	esac
	[ -f "$blockfile" ] && [ -r "$blockfile" ] || return 3

	if [ "$state" -eq 0 ]; then
		local lb le cur new
		lb="$(mb_fenced_line_matches "$file" "$MB_DESIGN_BEGIN" | head -1)"
		le="$(mb_fenced_line_matches "$file" "$MB_DESIGN_END" | head -1)"
		cur="$(sed -n "${lb},${le}p" "$file")"
		new="$(cat "$blockfile")"
		[ "$cur" = "$new" ] && return 4
		tmp="$(mktemp "$(dirname -- "$file")/.mockingbird-tmp.XXXXXX")" || return 1
		{
			[ "$lb" -gt 1 ] && sed -n "1,$((lb - 1))p" "$file"
			cat "$blockfile"
			sed -n "$((le + 1)),\$p" "$file"
		} > "$tmp"
		mv -- "$tmp" "$file"
		return 0
	fi

	# state == 1: no existing block. Insert just above a fenced-filtered
	# security begin marker if one exists, otherwise append at EOF.
	local secline
	secline="$(mb_fenced_line_matches "$file" "$MB_SECURITY_BEGIN" | head -1)"
	tmp="$(mktemp "$(dirname -- "$file")/.mockingbird-tmp.XXXXXX")" || return 1
	if [ -n "$secline" ]; then
		{
			[ "$secline" -gt 1 ] && sed -n "1,$((secline - 1))p" "$file"
			cat "$blockfile"
			printf '\n'
			sed -n "${secline},\$p" "$file"
		} > "$tmp"
	else
		{
			cat "$file"
			printf '\n'
			cat "$blockfile"
		} > "$tmp"
	fi
	mv -- "$tmp" "$file"
	return 0
}
