#!/usr/bin/env bash
# Deterministic scorer for mockingbird-bench. Only jq + awk, no LLM involved
# here — mirrors footgun's test/bench/score.sh shape and its --self-test
# idea: prove the scoring LOGIC is correct on synthetic input before ever
# trusting it on a real, non-deterministic LLM run.
#
# Findings/golden JSON shape (array of objects):
#   { "element": "UI-X", "stage": "semantic", "class": "violated",
#     "terminal": "src/f.ts:12" }   <- terminal optional, used by --mode honesty
#
# Matching rule: (element, stage) identifies a case. Exact class match is a
# full credit (1.0); same (element, stage) present in both but a different
# class is a partial credit (0.5) — the locator found the right seam but
# classified it differently, which is a milder miss than not finding it at
# all. Missing entirely is 0.
#
# Modes:
#   --mode recall  <findings.json> <golden.json>   prints recall=.. precision=.. f1=..
#   --mode fp      <findings.json> <golden.json>   prints fp=..  (false positives on a clean fixture)
#   --mode honesty <findings.json>                 prints hallu=.. (violated findings with no terminal link)
#   --self-test                                     synthetic fixtures, no LLM, no real findings needed
#
# Exit: 0 = threshold met · 1 = threshold missed · 2 = usage
set -u
# Every arithmetic awk call below both parses and prints decimal fractions.
# Under a locale whose LC_NUMERIC uses a comma (e.g. de_DE), awk's own
# printf emits "1,0000" instead of "1.0000" AND fails to correctly parse a
# "0.5" fed back into it as input -- silently reading it as 0. Locale-
# independent scoring is not optional here, so it is forced for the whole
# script rather than re-derived per awk call.
export LC_ALL=C
RECALL_MIN="${RECALL_MIN:-0.8}"
FP_MAX="${FP_MAX:-0}"
HALLU_MAX="${HALLU_MAX:-0}"

usage() { echo "usage: score.sh --mode recall|fp|honesty FILES... | --self-test" >&2; exit 2; }

_match_credits() {
	# Prints one credit (1, 0.5, or 0) per golden entry, on stdout.
	local findings="$1" golden="$2"
	jq -n --slurpfile f "$findings" --slurpfile g "$golden" -r '
		($f[0] // []) as $F | ($g[0] // []) as $G |
		$G[] | . as $ge |
		( [ $F[] | select(.element == $ge.element and .stage == $ge.stage) ] ) as $matches |
		if ($matches | length) == 0 then 0
		elif ($matches | map(select(.class == $ge.class)) | length) > 0 then 1
		else 0.5
		end
	'
}

mode_recall() {
	[ $# -eq 2 ] || usage
	local findings="$1" golden="$2"
	[ -f "$findings" ] && [ -f "$golden" ] || { echo "no such file" >&2; exit 2; }
	local ngold nfind credits
	ngold="$(jq 'length' "$golden")"
	nfind="$(jq '[.[] | select(true)] | length' "$findings")"
	credits="$(_match_credits "$findings" "$golden" | awk '{s+=$1} END{printf "%.4f", s+0}')"
	local recall precision f1
	if [ "$ngold" -eq 0 ]; then recall="1.0000"; else
		recall="$(awk -v c="$credits" -v n="$ngold" 'BEGIN{printf "%.4f", c/n}')"
	fi
	if [ "$nfind" -eq 0 ]; then precision="0.0000"; else
		precision="$(awk -v c="$credits" -v n="$nfind" 'BEGIN{printf "%.4f", (c>n?n:c)/n}')"
	fi
	f1="$(awk -v r="$recall" -v p="$precision" 'BEGIN{ if (r+p==0) printf "0.0000"; else printf "%.4f", 2*r*p/(r+p) }')"
	echo "recall=$recall precision=$precision f1=$f1"
	awk -v r="$recall" -v min="$RECALL_MIN" 'BEGIN{exit (r+0 >= min+0) ? 0 : 1}'
}

mode_fp() {
	[ $# -eq 2 ] || usage
	local findings="$1" golden="$2"
	[ -f "$findings" ] && [ -f "$golden" ] || { echo "no such file" >&2; exit 2; }
	# A false positive is any finding classified violated/partial whose
	# (element, stage) has no corresponding golden entry at all. An
	# unverified:* finding is never a false positive on its own — it is a
	# refusal to judge, not a flagged deviation.
	local fp
	fp="$(jq -n --slurpfile f "$findings" --slurpfile g "$golden" '
		($f[0] // []) as $F | ($g[0] // []) as $G |
		[ $F[] | select(.class == "violated" or .class == "partial") | . as $fe |
		  select(([ $G[] | select(.element == $fe.element and .stage == $fe.stage) ] | length) == 0) ]
		| length
	')"
	echo "fp=$fp"
	awk -v n="$fp" -v max="$FP_MAX" 'BEGIN{exit (n+0 <= max+0) ? 0 : 1}'
}

mode_honesty() {
	[ $# -eq 1 ] || usage
	local findings="$1"
	[ -f "$findings" ] || { echo "no such file" >&2; exit 2; }
	local total noterm
	total="$(jq '[.[] | select(.class == "violated")] | length' "$findings")"
	noterm="$(jq '[.[] | select(.class == "violated") | select((.terminal // "") == "")] | length' "$findings")"
	local hallu
	if [ "$total" -eq 0 ]; then hallu="0.0000"; else
		hallu="$(awk -v n="$noterm" -v t="$total" 'BEGIN{printf "%.4f", n/t}')"
	fi
	echo "hallu=$hallu (of $total 'violated' findings, $noterm without a terminal link)"
	awk -v h="$hallu" -v max="$HALLU_MAX" 'BEGIN{exit (h+0 <= max+0) ? 0 : 1}'
}

self_test() {
	local tmp fail=0
	tmp="$(mktemp -d)"
	trap 'rm -rf -- "$tmp"' RETURN

	# Perfect recall: findings match golden exactly.
	printf '[{"element":"UI-A","stage":"semantic","class":"violated","terminal":"f.ts:1"}]' > "$tmp/g1.json"
	cp "$tmp/g1.json" "$tmp/f1.json"
	OUT="$(mode_recall "$tmp/f1.json" "$tmp/g1.json")"; RC=$?
	[ "$OUT" = "recall=1.0000 precision=1.0000 f1=1.0000" ] && [ "$RC" -eq 0 ] \
		&& echo "self-test: PASS  perfect recall" || { echo "self-test: FAIL  perfect recall: $OUT rc=$RC"; fail=1; }

	# Partial credit: same element/stage, wrong class.
	printf '[{"element":"UI-A","stage":"semantic","class":"partial"}]' > "$tmp/f2.json"
	OUT="$(mode_recall "$tmp/f2.json" "$tmp/g1.json")"
	[ "$OUT" = "recall=0.5000 precision=0.5000 f1=0.5000" ] \
		&& echo "self-test: PASS  partial credit on class mismatch" || { echo "self-test: FAIL  partial credit: $OUT"; fail=1; }

	# Zero recall: nothing found.
	printf '[]' > "$tmp/f3.json"
	mode_recall "$tmp/f3.json" "$tmp/g1.json" > "$tmp/o3.txt"; RC=$?
	grep -q '^recall=0.0000' "$tmp/o3.txt" && [ "$RC" -eq 1 ] \
		&& echo "self-test: PASS  zero recall below threshold fails" || { echo "self-test: FAIL  zero recall: $(cat "$tmp/o3.txt") rc=$RC"; fail=1; }

	# False positives: a clean golden (empty) with one violated finding -> fp=1.
	printf '[]' > "$tmp/gclean.json"
	printf '[{"element":"UI-B","stage":"semantic","class":"violated"}]' > "$tmp/ffp.json"
	OUT="$(mode_fp "$tmp/ffp.json" "$tmp/gclean.json")"; RC=$?
	[ "$OUT" = "fp=1" ] && [ "$RC" -eq 1 ] \
		&& echo "self-test: PASS  fp counted and fails the default threshold" || { echo "self-test: FAIL  fp: $OUT rc=$RC"; fail=1; }

	# unverified:* is never a false positive.
	printf '[{"element":"UI-B","stage":"semantic","class":"unverified:external-boundary"}]' > "$tmp/fun.json"
	OUT="$(mode_fp "$tmp/fun.json" "$tmp/gclean.json")"; RC=$?
	[ "$OUT" = "fp=0" ] && [ "$RC" -eq 0 ] \
		&& echo "self-test: PASS  unverified is not a false positive" || { echo "self-test: FAIL  unverified fp: $OUT rc=$RC"; fail=1; }

	# Honesty: a violated finding with no terminal is a hallucination.
	printf '[{"element":"UI-A","stage":"semantic","class":"violated"},{"element":"UI-B","stage":"semantic","class":"violated","terminal":"f.ts:1"}]' > "$tmp/fh.json"
	OUT="$(mode_honesty "$tmp/fh.json")"; RC=$?
	case "$OUT" in
		'hallu=0.5000 '*) [ "$RC" -eq 1 ] && echo "self-test: PASS  honesty rate computed" || { echo "self-test: FAIL  honesty rc: $RC"; fail=1; } ;;
		*) echo "self-test: FAIL  honesty: $OUT"; fail=1 ;;
	esac

	if [ "$fail" -eq 0 ]; then echo "self-test: PASS (all checks)"; return 0; else echo "self-test: FAIL"; return 1; fi
}

[ $# -ge 1 ] || usage
case "$1" in
	--self-test) self_test; exit $? ;;
	--mode)
		shift
		[ $# -ge 1 ] || usage
		m="$1"; shift
		case "$m" in
			recall) mode_recall "$@" ;;
			fp) mode_fp "$@" ;;
			honesty) mode_honesty "$@" ;;
			*) usage ;;
		esac
		;;
	*) usage ;;
esac
