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
