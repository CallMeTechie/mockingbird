#!/usr/bin/env bash
# Render the mockingbird design marker block (facts comment + UI Requirements
# table + prose list of consumed elements) for a spec, from manifest.yaml.
# Prints the block, markers included, to stdout — mb-insert-block.sh writes it
# into a file.
#
# Usage: mb-render-block.sh --root DIR [--screens ID,ID,...] [--consumes ID,ID,...]
#   --root       project root (the directory containing docs/design/)
#   --screens    screen IDs this spec owns; default: every screen in the
#                manifest (the single-spec case, before any /design-split)
#   --consumes   element IDs this spec's screens use but do not own, e.g. a
#                shared UI-SHELL-NAV pulled in via a screen's `uses:` list.
#                v0.1 scope: the caller supplies this explicitly (read from
#                the manifest's `uses:` fields) rather than the script
#                deriving it, because the strict-subset parser does not parse
#                `uses:` — see mockingbird-manifest.awk.
#
# Exit: 0 ok · 2 usage error · 3 manifest or a referenced file missing ·
#       6 manifest fails semantic validation.
set -u
# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PLUGIN_ROOT="$(dirname -- "$HERE")"
. "$PLUGIN_ROOT/lib/mockingbird-manifestlib.sh"
. "$PLUGIN_ROOT/hooks/mockingbird-hooklib.sh"
. "$PLUGIN_ROOT/lib/mockingbird-blocklib.sh"

ROOT="" SCREENS="" CONSUMES=""
while [ $# -gt 0 ]; do
	case "$1" in
		--root) ROOT="$2"; shift 2 ;;
		--screens) SCREENS="$2"; shift 2 ;;
		--consumes) CONSUMES="$2"; shift 2 ;;
		*) echo "usage: mb-render-block.sh --root DIR [--screens ID,ID] [--consumes ID,ID]" >&2; exit 2 ;;
	esac
done
[ -n "$ROOT" ] || { echo "usage: --root is required" >&2; exit 2; }

MANIFEST="$ROOT/docs/design/manifest.yaml"
[ -f "$MANIFEST" ] || { echo "no manifest at $MANIFEST" >&2; exit 3; }

ERR="$(MB_VALIDATE_ROOT="$ROOT" mb_manifest_validate "$MANIFEST" 2>&1 1>/dev/null)"
RC=$?
if [ "$RC" -ne 0 ]; then [ -n "$ERR" ] && printf '%s\n' "$ERR" >&2; exit "$RC"; fi

META="$(mb_manifest_meta "$MANIFEST")"
meta_get() { printf '%s\n' "$META" | awk -F'\t' -v k="$1" '$1==k{print $2; exit}'; }
REV="$(meta_get revision)"
SYS="$(meta_get design_system)"
IDX="$(meta_get mockups_index)"
ADAPTER="$(meta_get primary_adapter)"
DHASH="$(mb_design_hash "$ROOT")"
[ -n "$DHASH" ] || { echo "could not hash $ROOT/docs/design" >&2; exit 3; }

TSV="$(mb_manifest_to_tsv "$MANIFEST")"

if [ -z "$SCREENS" ]; then
	SCREENS="$(printf '%s\n' "$TSV" | cut -f"$MB_F_SCREEN_ID" | sort -u | paste -sd, -)"
fi

FACTS="<!-- design: manifest=docs/design/manifest.yaml design_rev=$REV design_hash=sha256:$DHASH"
FACTS="$FACTS system=$SYS index=$IDX adapter=$ADAPTER screens=$SCREENS"
[ -n "$CONSUMES" ] && FACTS="$FACTS consumes=$CONSUMES"
FACTS="$FACTS -->"

printf '%s\n' "$MB_DESIGN_BEGIN"
printf '%s\n' "$FACTS"
cat <<'PROSE'
<!-- Generiert aus docs/design/manifest.yaml. Nicht von Hand ändern —
     Änderungen hier werden beim nächsten mockingbird-Lauf überschrieben.
     Design ändern heißt Manifest ändern. -->
PROSE
printf '\n## UI Requirements\n\n'
printf '| ID | Element | Screen | Status | Fachlicher Anker |\n'
printf '|----|---------|--------|--------|------------------|\n'

printf '%s\n' "$TSV" | while IFS=$'\t' read -r scr_id _scr_kind _scr_artboard elem_id _elem_type elem_label \
	elem_status _elem_verify _elem_ds sa_means _sa_concept _sa_aliases sa_not \
	_states _loc_web _reason_deferred _reason_skip; do
	[ -n "$elem_id" ] || continue
	case ",$SCREENS," in *",$scr_id,"*) ;; *) continue ;; esac
	anchor="$sa_means"
	[ "$anchor" = "-" ] && anchor=""
	if [ "$sa_not" != "-" ] && [ -n "$sa_not" ]; then
		anchor="${anchor:+$anchor }Nicht: $(printf '%s' "$sa_not" | sed 's/,/, /g')."
	fi
	[ -n "$anchor" ] || anchor="—"
	printf '| %s | %s | %s | %s | %s |\n' "$elem_id" "$elem_label" "$scr_id" "$elem_status" "$anchor"
done

if [ -n "$CONSUMES" ]; then
	printf '\n**Übernommene Elemente** (hier nicht zu bauen, nur zu verwenden):\n'
	IFS=',' read -r -a _mb_consumed <<< "$CONSUMES"
	for cid in "${_mb_consumed[@]}"; do
		row="$(printf '%s\n' "$TSV" | awk -F'\t' -v id="$cid" '$4==id{print; exit}')"
		if [ -n "$row" ]; then
			clabel="$(mb_tsv_field "$row" "$MB_F_ELEMENT_LABEL")"
			printf -- '- `%s` — %s\n' "$cid" "$clabel"
		else
			printf -- '- `%s`\n' "$cid"
		fi
	done
fi

printf '\nArtboards: `%s` · Design-System: `%s`\n' "$IDX" "$SYS"
printf '%s\n' "$MB_DESIGN_END"
