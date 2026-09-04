#!/usr/bin/env bash
# Deterministic half of /design-check: manifest validity, block freshness in
# every spec, the split invariants from carrying-design-through/references/
# splitting.md, and per-task design coverage in every plan. Read-only.
# Prints "Befund | Ort | Schwere" lines; exit 0 = no finding, 1 = findings,
# 3 = no manifest.
set -u
# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PLUGIN_ROOT="$(dirname -- "$HERE")"
. "$PLUGIN_ROOT/lib/mockingbird-manifestlib.sh"
. "$PLUGIN_ROOT/lib/mockingbird-blocklib.sh"
. "$PLUGIN_ROOT/hooks/mockingbird-hooklib.sh"

ROOT="${1:-.}"
MANIFEST="$ROOT/docs/design/manifest.yaml"
[ -f "$MANIFEST" ] || { echo "kein Manifest unter $MANIFEST" >&2; exit 3; }

findings=0
finding() { printf '%s | %s | %s\n' "$1" "$2" "$3"; findings=$((findings + 1)); }

# 1. Manifest itself.
ERR="$(MB_VALIDATE_ROOT="$ROOT" mb_manifest_validate "$MANIFEST" 2>&1 1>/dev/null)"; RC=$?
if [ "$RC" -ne 0 ]; then
	while IFS= read -r l; do [ -n "$l" ] && finding "Manifest: $l" "docs/design/manifest.yaml" "blocker"; done <<< "$ERR"
	[ "$RC" -eq 5 ] && finding "Manifest außerhalb des Parser-Subsets (Exit 5)" "docs/design/manifest.yaml" "blocker"
	printf 'VERDICT: %d Befund(e)\n' "$findings"; exit 1
fi

TSV="$(mb_manifest_to_tsv "$MANIFEST")"
DHASH="$(mb_design_hash "$ROOT")"
REV="$(mb_manifest_meta "$MANIFEST" | awk -F'\t' '$1=="revision"{print $2; exit}')"
ALL_SCREENS="$(printf '%s\n' "$TSV" | cut -f1 | sort -u)"
ALLOCS="$(mb_manifest_allocations "$MANIFEST")"

# 1b. Every screen that names a guide must have it; a guide named nowhere is
# fine (v0.1 keeps it recommended, not required).
awk '/^  - id:/{cur=$0; sub(/^  - id:[ \t]*/,"",cur)} /^    guide:/{g=$0; sub(/^    guide:[ \t]*/,"",g); gsub(/^"|"$/,"",g); print cur "\t" g}' "$MANIFEST" \
| while IFS=$'\t' read -r sid g; do
	[ -n "$g" ] || continue
	[ -f "$ROOT/$g" ] || echo "Umsetzungsanleitung fehlt: $g | $sid | important"
done > "${TMPDIR:-/tmp}/mb-guides.$$"
if [ -s "${TMPDIR:-/tmp}/mb-guides.$$" ]; then cat "${TMPDIR:-/tmp}/mb-guides.$$"; findings=$((findings + $(wc -l < "${TMPDIR:-/tmp}/mb-guides.$$"))); fi
rm -f "${TMPDIR:-/tmp}/mb-guides.$$"

# 1c. The artboards' token mirror (tokens_css) must not drift from the
# project's real token definitions (token_definitions): every --name in the
# mirror must be defined for real, and a name defined exactly once for real
# must carry the same value in the mirror. Themed tokens (defined more than
# once) are name-checked only.
TOKENS_CSS="$(mb_manifest_meta "$MANIFEST" | awk -F'\t' '$1=="tokens_css"{print $2; exit}')"
TOKDEFS="$(mb_manifest_meta "$MANIFEST" | awk -F'\t' '$1=="token_definitions"{print $2; exit}' | tr ',' ' ')"
if [ -n "$TOKDEFS" ] && [ -f "$ROOT/$TOKENS_CSS" ]; then
	# normalise first (whitespace, rgba spelling, hex case), THEN split name
	# from value on the first colon -- splitting first and squashing whitespace
	# afterwards ate the separator (found the hard way).
	norm() { sed -E 's|//.*$||; s/[[:space:]]+/ /g; s/rgba\(([0-9]+), ?([0-9]+), ?([0-9]+), ?0?\.([0-9]+)\)/rgba(\1,\2,\3,.\4)/g; s/ *$//' | tr 'A-F' 'a-f' | awk '{ i = index($0, ":"); if (i == 0) next; n = substr($0, 1, i - 1); v = substr($0, i + 1); gsub(/^ +| +$/, "", n); gsub(/^ +| +$/, "", v); print n "\t" v }'; }
	DEFS="$(for d in $TOKDEFS; do [ -f "$ROOT/$d" ] && grep -oE -- '--[A-Za-z0-9_-]+ *: *[^;{}]+' "$ROOT/$d"; done | norm | sort)"
	MIR="$(tr ';' '\n' < "$ROOT/$TOKENS_CSS" | grep -oE -- '--[A-Za-z0-9_-]+ *: *[^;{}]+' | norm | sort)"
	printf '%s\n' "$MIR" | cut -f1 | sort -u | while read -r n; do
		[ -n "$n" ] || continue
		case "$n" in --ui-scale|--title-bar-height|--key-bar-height|--mobile-nav-height|--content-height|--safe-area-top) continue ;; esac
		printf '%s\n' "$DEFS" | cut -f1 | grep -qx -- "$n" || echo "Token nur im Spiegel, nicht im Produktivcode: $n | $TOKENS_CSS | important"
	done > "${TMPDIR:-/tmp}/mb-tok.$$"
	printf '%s\n' "$DEFS" | cut -f1 | sort | uniq -c | awk '$1==1{print $2}' | while read -r n; do
		dv="$(printf '%s\n' "$DEFS" | awk -F'\t' -v n="$n" '$1==n{print $2; exit}')"
		mv_="$(printf '%s\n' "$MIR" | awk -F'\t' -v n="$n" '$1==n{print $2; exit}')"
		[ -z "$mv_" ] && { echo "Token im Produktivcode, fehlt im Spiegel: $n | $TOKENS_CSS | important"; continue; }
		[ "$dv" = "$mv_" ] || echo "Token-Wert weicht ab: $n (Code: $dv / Spiegel: $mv_) | $TOKENS_CSS | important"
	done >> "${TMPDIR:-/tmp}/mb-tok.$$"
	if [ -s "${TMPDIR:-/tmp}/mb-tok.$$" ]; then cat "${TMPDIR:-/tmp}/mb-tok.$$"; findings=$((findings + $(wc -l < "${TMPDIR:-/tmp}/mb-tok.$$"))); fi
	rm -f "${TMPDIR:-/tmp}/mb-tok.$$"
fi

# 1d. Run state under <project>/.claude/ is per-machine, per-run bookkeeping.
# If git tracks it, every run dirties the working tree and the state travels
# to other machines as if it were a fact about them (happened on Outpost:
# a broad `git add -A` swept .mockingbird-verified into a commit).
if [ -d "$ROOT/.git" ] && command -v git >/dev/null 2>&1; then
	TRACKED="$(git -C "$ROOT" ls-files ".claude/.mockingbird-*" 2>/dev/null)"
	if [ -n "$TRACKED" ]; then
		while IFS= read -r t; do
			[ -n "$t" ] && finding "Laufzustand wird versioniert (gehört in .gitignore: .claude/.mockingbird-*)" "$t" "important"
		done <<< "$TRACKED"
	fi
fi

# 2. Every spec with a block: freshness and the always-present facts.
for spec in "$ROOT"/docs/superpowers/specs/*-design.md; do
	[ -f "$spec" ] || continue
	rel="${spec#"$ROOT"/}"
	mb_design_block_state "$spec"; st=$?
	case "$st" in
		1) continue ;;
		2) finding "Design-Block beschädigt (Marker einseitig/doppelt/vertauscht)" "$rel" "blocker"; continue ;;
	esac
	mb_design_facts_valid "$spec" || finding "Fakten-Kommentar ungültig" "$rel" "blocker"
	raw="$(mb_design_facts_raw "$spec")"
	for k in manifest system index; do
		mb_fact_get "$raw" "$k" >/dev/null || finding "Block ohne $k=" "$rel" "blocker"
	done
	bh="$(mb_fact_get "$raw" design_hash)"; bh="${bh#sha256:}"
	[ "$bh" = "$DHASH" ] || finding "Design-Block veraltet (design_hash ≠ aktuelles docs/design/)" "$rel" "important"
	br="$(mb_fact_get "$raw" design_rev)"
	if [ -n "$br" ] && [ -n "$REV" ] && [ "$br" -gt "$REV" ] 2>/dev/null; then
		finding "design_rev $br im Block > Manifest-revision $REV" "$rel" "blocker"
	fi
done

# 3. Split invariants -- only when allocations: exist.
if [ -n "$ALLOCS" ]; then
	owners=""
	while IFS=$'\t' read -r spec owns _consumes; do
		[ -n "$spec" ] || continue
		[ -f "$ROOT/$spec" ] || finding "Zugeordnete Spec existiert nicht" "$spec" "blocker"
		for scr in ${owns//,/ }; do
			[ "$scr" != "-" ] || continue
			case " $owners " in *" $scr "*) finding "Screen $scr hat mehr als einen Owner" "docs/design/manifest.yaml" "blocker" ;; esac
			owners="$owners $scr"
		done
		if [ -f "$ROOT/$spec" ] && mb_design_block_state "$ROOT/$spec"; then
			bs="$(mb_fact_get "$(mb_design_facts_raw "$ROOT/$spec")" screens)"
			want="$(printf '%s' "$owns" | tr ',' '\n' | sort | paste -sd, -)"
			have="$(printf '%s' "$bs" | tr ',' '\n' | sort | paste -sd, -)"
			[ "$want" = "$have" ] || finding "Block screens=$bs ≠ allocations owns=$owns" "$spec" "important"
		fi
	done <<< "$ALLOCS"
	while IFS= read -r scr; do
		[ -n "$scr" ] || continue
		case " $owners " in *" $scr "*) ;; *) finding "Screen $scr in keiner allocations-Zeile" "docs/design/manifest.yaml" "important" ;; esac
	done <<< "$ALL_SCREENS"
fi

# 4. Plans: every task carries a Design: line (table or "kein UI-Anteil").
for plan in "$ROOT"/docs/superpowers/plans/*.md; do
	[ -f "$plan" ] || continue
	rel="${plan#"$ROOT"/}"
	grep -qF 'docs/design/manifest.yaml' "$plan" || { finding "Plan nennt docs/design/manifest.yaml nicht (Kanal A/B fehlen)" "$rel" "important"; continue; }
	awk -v rel="$rel" '
		/^```/ { fence = !fence }
		!fence && /^#+[ \t]+Task[ \t]+[0-9]+/ { if (intask && !seen) printf "Task ohne **Design:**-Zeile | %s (%s) | important\n", rel, name; intask=1; seen=0; name=$0; sub(/^#+[ \t]+/,"",name); sub(/:.*$/,"",name); next }
		intask && /^\*\*Design:\*\*/ { seen=1 }
		END { if (intask && !seen) printf "Task ohne **Design:**-Zeile | %s (%s) | important\n", rel, name }
	' "$plan" | while IFS= read -r l; do [ -n "$l" ] && { printf '%s\n' "$l"; findings=$((findings + 1)); }; done
done

# The awk|while above runs in a subshell; recount plan findings from stdout is
# not possible, so re-derive the count for the exit code.
plan_findings="$(for plan in "$ROOT"/docs/superpowers/plans/*.md; do
	[ -f "$plan" ] || continue
	grep -qF 'docs/design/manifest.yaml' "$plan" || continue
	awk '/^```/ { fence = !fence } !fence && /^#+[ \t]+Task[ \t]+[0-9]+/ { if (intask && !seen) c++; intask=1; seen=0; next } intask && /^\*\*Design:\*\*/ { seen=1 } END { if (intask && !seen) c++; print c+0 }' "$plan"
done | awk '{s+=$1} END{print s+0}')"
findings=$((findings + plan_findings))

printf 'VERDICT: %d Befund(e)\n' "$findings"
[ "$findings" -eq 0 ]
