# shellcheck disable=SC2034  # several read fields are for column alignment only
# shellcheck shell=bash
# Deterministic rules on top of reviewer output: the seam anti-hallucination
# checks and the coverage verdict. Sourced by mockingbird-scope.sh and by
# tests. The reviewers (LLM) produce MB-SEAM and MB-COVERAGE blocks; nothing
# past this file ever asks an LLM to reconsider a classification — the
# verdict is computed here, in bash, on purpose (a stricter rule than
# footgun's aggregator, which lets its own consolidator LLM phrase the
# verdict).

# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
_MB_COVERAGELIB_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$_MB_COVERAGELIB_DIR/mockingbird-manifestlib.sh"

# --- mb_check_seam ----------------------------------------------------------
#
# Reads an MB-SEAM block (one data line per element):
#   <id> | tier=A|B|C | render=<f:l|-> | binding=<f:l|-> | source=<f:l|-> |
#   handler=<f:l|-> | terminal=<f:l|-> | found=<concept> |
#   ok|partial|violated|unverified:<reason>
#
# and applies four rules, none of them a judgement call:
#   1. "violated" without an existing terminal=file:line -> unverified:no-locator
#   2. any file:line whose file does not exist under <root>, or lies outside
#      <root> (../ escape) or under node_modules -> whole line -> unverified:no-locator
#   3. "unverified:*" with not a single link filled in ("-" everywhere) ->
#      unverified:no-locator (laziness costs: "I couldn't even show where I
#      stopped looking" is indistinguishable from "not implemented")
#   4. tier=C can never justify "violated" -> downgraded to "partial", with
#      " [Locator schwach]" appended to the reason
#
# Prints the (possibly downgraded) lines to stdout, one per input line.
# Malformed input lines are passed through unchanged with a leading
# "MALFORMED: " marker, never silently dropped and never guessed at.
mb_check_seam() {
	local seamfile="$1" root="$2" line
	[ -f "$seamfile" ] || return 3
	while IFS= read -r line; do
		[ -n "$line" ] || continue
		case "$line" in MB-SEAM|END) continue ;; esac
		_mb_check_seam_line "$line" "$root"
	done < "$seamfile"
}

_mb_seam_field() {
	printf '%s' "$1" | awk -F'\\|' -v k="$2" '{
		for (i = 1; i <= NF; i++) {
			f = $i; gsub(/^[ \t]+|[ \t]+$/, "", f)
			if (index(f, k "=") == 1) { print substr(f, length(k) + 2); exit }
		}
	}'
}

_mb_locator_exists() {
	local loc="$1" root="$2" file
	[ -n "$loc" ] && [ "$loc" != "-" ] || return 1
	file="${loc%:*}"
	case "$file" in
		/*) return 1 ;;                        # absolute paths never legitimate here
		*node_modules*) return 1 ;;
		../*|*/../*) return 1 ;;                # no escaping the project root
	esac
	[ -f "$root/$file" ]
}

_mb_check_seam_line() {
	local line="$1" root="$2" id tier verdict rest nf
	nf="$(printf '%s' "$line" | awk -F'\\|' '{print NF}')"
	id="$(printf '%s' "$line" | awk -F'\\|' '{f=$1; gsub(/^[ \t]+|[ \t]+$/,"",f); print f}')"
	# 9 pipe-separated fields expected: id, tier, render, binding, source,
	# handler, terminal, found, verdict. Fewer than that is not a seam line at
	# all -- flagged, never silently dropped or guessed at.
	if [ -z "$id" ] || [ "$nf" -lt 9 ]; then printf 'MALFORMED: %s\n' "$line"; return; fi

	tier="$(_mb_seam_field "$line" tier)"
	verdict="$(printf '%s' "$line" | awk -F'\\|' '{f=$NF; gsub(/^[ \t]+|[ \t]+$/,"",f); print f}')"

	# Rule 2: check every file:line-shaped field; any bad one poisons the line.
	local any_link=0 bad_link=0 f
	for f in render binding source handler terminal; do
		local v
		v="$(_mb_seam_field "$line" "$f")"
		if [ -n "$v" ] && [ "$v" != "-" ]; then
			any_link=1
			_mb_locator_exists "$v" "$root" || bad_link=1
		fi
	done
	if [ "$bad_link" -eq 1 ]; then
		rest="$(printf '%s' "$line" | sed 's/|[^|]*$//')"
		printf '%s| unverified:no-locator [bad file:line]\n' "$rest"
		return
	fi

	# Rule 3: an "unverified:*" verdict with nothing at all linked.
	case "$verdict" in
		unverified:*)
			if [ "$any_link" -eq 0 ]; then
				rest="$(printf '%s' "$line" | sed 's/|[^|]*$//')"
				printf '%s| unverified:no-locator\n' "$rest"
				return
			fi
			;;
	esac

	# Rule 1: "violated" needs a terminal link.
	if [ "$verdict" = "violated" ]; then
		local terminal
		terminal="$(_mb_seam_field "$line" terminal)"
		if [ -z "$terminal" ] || [ "$terminal" = "-" ]; then
			rest="$(printf '%s' "$line" | sed 's/|[^|]*$//')"
			printf '%s| unverified:no-locator\n' "$rest"
			return
		fi
	fi

	# Rule 4: tier C never justifies "violated".
	if [ "$verdict" = "violated" ] && [ "$tier" = "C" ]; then
		rest="$(printf '%s' "$line" | sed 's/|[^|]*$//')"
		printf '%s| partial [Locator schwach]\n' "$rest"
		return
	fi

	printf '%s\n' "$line"
}

# --- mb_manifest_coverage ---------------------------------------------------
#
# Reads MB-COVERAGE data lines ("<id> | <stage> | <class> | <loc>") from
# <coveragefile>, cross-references them against <manifestfile>'s elements
# and their verify: status, and prints a report ending in a verdict line
# "VERDICT: MATCH" | "VERDICT: MATCH WITH NOTES" | "VERDICT: MISMATCH".
# Returns 0 for MATCH/MATCH WITH NOTES, 1 for MISMATCH, 3/4/5 propagated
# from manifest loading.
#
# Rules (numbered to match carrying-design-through/references/plan-propagation.md#kanal-d):
#   1. required (or verify:skip without a reason -- rule 7) + a blocking
#      stage (structure/semantic/flow) on violated or partial -> MISMATCH
#   2. same, on unverified:no-locator -> MISMATCH
#   3. unverified:external-boundary/dynamic/out-of-scope -> never verdict
#      affecting, listed as an open gap
#   4. recommended + violated -> Important, verdict untouched
#   5. states/tokens stages never affect the verdict
#   6. an element with NO coverage line at all counts as unverified:no-locator,
#      never ok -- silence is never a pass
#   7. verify:skip WITH a reason is excluded from the denominator entirely;
#      WITHOUT a reason it is treated as required
mb_manifest_coverage() {
	local coveragefile="$1" manifestfile="$2" root="${3:-}"
	[ -f "$coveragefile" ] || return 3
	local tsv
	tsv="$(mb_manifest_to_tsv "$manifestfile")"; local rc=$?
	[ "$rc" -eq 0 ] || return "$rc"

	local blockers="" importants="" gaps=""
	local mismatch=0

	while IFS=$'\t' read -r scr_id _sk _sa elem_id _et _el elem_status elem_verify \
		_eds _sam _sac _saa _san _states _lw _rd reason_skip _uses; do
		[ -n "$elem_id" ] || continue
		local required=1
		if [ "$elem_verify" = "skip" ]; then
			if [ "$reason_skip" != "-" ] && [ -n "$reason_skip" ]; then
				continue
			fi
			required=1
		elif [ "$elem_verify" = "recommended" ]; then
			required=0
		fi

		local lines
		lines="$(awk -F'\\|' -v id="$elem_id" '
			{ f=$1; gsub(/^[ \t]+|[ \t]+$/,"",f); if (f==id) print }
		' "$coveragefile")"

		if [ -z "$lines" ]; then
			if [ "$required" -eq 1 ]; then
				blockers="$blockers$elem_id (kein Coverage-Eintrag)\n"
				mismatch=1
			else
				importants="$importants$elem_id: recommended, nie geprüft\n"
			fi
			continue
		fi

		local elem_bad=0 elem_important=0
		while IFS= read -r cl; do
			[ -n "$cl" ] || continue
			local stage class
			stage="$(printf '%s' "$cl" | awk -F'\\|' '{f=$2; gsub(/^[ \t]+|[ \t]+$/,"",f); print f}')"
			class="$(printf '%s' "$cl" | awk -F'\\|' '{f=$3; gsub(/^[ \t]+|[ \t]+$/,"",f); print f}')"
			# mb_check_seam annotates downgraded classes ("partial [Locator
			# schwach]", "unverified:no-locator [bad file:line]"). Only the
			# first word is the class; without this the annotated form matched
			# neither branch below and was silently ignored -- a downgraded
			# blocker would have vanished from the verdict.
			class="${class%% *}"
			case "$stage" in
				states|tokens) continue ;;
			esac
			case "$class" in
				unverified:external-boundary|unverified:dynamic|unverified:out-of-scope)
					gaps="$gaps$elem_id ($stage): $class\n"
					continue
					;;
			esac
			case "$class" in
				ok) ;;
				violated|partial|unverified:no-locator|unverified:*)
					if [ "$required" -eq 1 ]; then elem_bad=1; else elem_important=1; fi
					;;
			esac
		done <<< "$lines"

		if [ "$elem_bad" -eq 1 ]; then
			blockers="$blockers$elem_id\n"
			mismatch=1
		elif [ "$elem_important" -eq 1 ]; then
			importants="$importants$elem_id: recommended, abweichend\n"
		fi
	done <<< "$tsv"

	echo "== Coverage-Bericht =="
	if [ -n "$blockers" ]; then
		echo "-- Blocker (required) --"
		printf '%b' "$blockers"
	fi
	if [ -n "$importants" ]; then
		echo "-- Important (recommended) --"
		printf '%b' "$importants"
	fi
	if [ -n "$gaps" ]; then
		echo "-- Offene Lücken (nicht verdikt-wirksam) --"
		printf '%b' "$gaps"
	fi

	if [ "$mismatch" -eq 1 ]; then
		echo "VERDICT: MISMATCH"
		return 1
	elif [ -n "$importants" ]; then
		echo "VERDICT: MATCH WITH NOTES"
		return 0
	else
		echo "VERDICT: MATCH"
		return 0
	fi
}

# --- mb_seam_to_coverage ----------------------------------------------------
#
# Bridge: turn an (already --check-seam'd) MB-SEAM block into MB-COVERAGE
# lines for <stage> (semantic|flow), so the consolidation step never has to
# translate by hand -- the one place where judgement would otherwise have
# crept back in between two deterministic steps.
#   <id> | <stage> | <class-without-annotation> | <terminal, else render, else ->
# MALFORMED lines from mb_check_seam are passed through unchanged.
mb_seam_to_coverage() {
	local seamfile="$1" stage="$2" line id verdict terminal render loc
	[ -f "$seamfile" ] || return 3
	case "$stage" in semantic|flow) ;; *) echo "stage must be semantic or flow" >&2; return 2 ;; esac
	while IFS= read -r line; do
		[ -n "$line" ] || continue
		case "$line" in MB-SEAM|END) continue ;; MALFORMED:*) printf '%s\n' "$line"; continue ;; esac
		id="$(printf '%s' "$line" | awk -F'\\|' '{f=$1; gsub(/^[ \t]+|[ \t]+$/,"",f); print f}')"
		verdict="$(printf '%s' "$line" | awk -F'\\|' '{f=$NF; gsub(/^[ \t]+|[ \t]+$/,"",f); print f}')"
		verdict="${verdict%% *}"
		terminal="$(_mb_seam_field "$line" terminal)"
		render="$(_mb_seam_field "$line" render)"
		loc="-"
		if [ -n "$terminal" ] && [ "$terminal" != "-" ]; then loc="$terminal"
		elif [ -n "$render" ] && [ "$render" != "-" ]; then loc="$render"; fi
		printf '%s | %s | %s | %s\n' "$id" "$stage" "$verdict" "$loc"
	done < "$seamfile"
}
