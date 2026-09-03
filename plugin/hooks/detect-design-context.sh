#!/usr/bin/env bash
# PostToolUse hook: nudge mockingbird when a design artefact, spec or plan is
# written. Advisory only — it emits additionalContext and nothing else, and it
# exits 0 on every path. It can never block a tool call and never writes to any
# file the user cares about.
set -u

# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$HERE/mockingbird-hooklib.sh"

INPUT="$(cat)"

# Escape hatch for verifying what the harness actually puts in the payload
# (notably whether session_id is present). Off unless explicitly pointed at a
# file; writes the raw payload and nothing else.
if [ -n "${MOCKINGBIRD_DEBUG_PAYLOAD:-}" ]; then
	printf '%s\n' "$INPUT" >> "$MOCKINGBIRD_DEBUG_PAYLOAD" 2>/dev/null || true
fi

command -v jq >/dev/null 2>&1 || exit 0

FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
SESSION="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"

[ -n "$FILE" ] || exit 0
mb_path_ok "$FILE" || exit 0
FILE="$(mb_canon_path "$FILE")"

KIND="$(mb_detect_kind "$FILE")"
[ -n "$KIND" ] || exit 0

ROOT="$(mb_find_root "$FILE" "$CWD")"
[ -n "$ROOT" ] || exit 0

STATE="$ROOT/.claude/.mockingbird-synced"
LOCK="$ROOT/.claude/.mockingbird-running"
MANIFEST="$ROOT/docs/design/manifest.yaml"

# Project opt-out.
[ -f "$ROOT/.claude/.mockingbird-off" ] && exit 0

# Our own run is in progress: everything it writes is expected, stay quiet.
mb_is_locked "$LOCK" "$SESSION" && exit 0

# preflight is mid-review: it is about to rewrite this document anyway, and two
# nudges in one turn about the same file are noise. File convention only — no
# code dependency on preflight; without it this simply never matches.
mb_is_locked "$ROOT/.claude/.preflight-running" "" && exit 0

DESIGN_HASH="$(mb_design_hash "$ROOT")"
DOC_HASH="$(mb_hash "$FILE")"

emit() {
	jq -n --arg ctx "$1" --arg kind "$KIND" --arg file "$FILE" \
		'{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx,mockingbirdKind:$kind,mockingbirdPath:$file}}'
	exit 0
}

SEQ_HINT='Steht im selben Turn auch ein preflight-Hinweis: erst mockingbird, dann preflight — der Sync ändert das Dokument, ein davor gesetzter Review-Hash wäre sofort veraltet.'

case "$KIND" in
	manifest|system|artboard)
		# The design changed. Which documents now describe an older design?
		# This fires without anyone touching those documents, which is the
		# whole point: drift is detected at the source, not on next contact.
		[ -n "$DESIGN_HASH" ] || exit 0
		STALE="$(mb_stale_docs "$STATE" "$DESIGN_HASH")"
		[ -n "$STALE" ] || exit 0
		LIST="$(printf '%s' "$STALE" | sed "s|^$ROOT/||" | sed 's/^/  - /')"
		emit "Das Design in docs/design/ wurde geändert. Diese Dokumente tragen einen veralteten Design-Block:
$LIST
Rufe den Skill carrying-design-through (mockingbird) mit mode=sync auf. $SEQ_HINT"
		;;

	spec)
		if [ ! -f "$MANIFEST" ]; then
			# No design exists yet. Only speak up if the spec actually reads
			# like it describes a user interface, and only once per version of
			# the document — a false positive here is pure annoyance.
			mb_already_synced "$STATE" "$FILE" "$DOC_HASH" "no-manifest" && exit 0
			grep -qiE '(^|[^a-z])(ui|ux|screen|frontend|ansicht|oberfläche|formular|button|dashboard|seite|view|layout|maske|dialog|tui|widget)([^a-z]|$)' -- "$FILE" 2>/dev/null || exit 0
			mb_record_synced "$STATE" "$FILE" "$DOC_HASH" "no-manifest" 2>/dev/null || true
			emit "Diese Spec beschreibt eine Oberfläche, aber das Projekt hat noch kein Design in docs/design/. Wenn das Aussehen und Verhalten festgeschrieben werden soll, ist /design der richtige nächste Schritt — sonst ignoriere diesen Hinweis."
		fi
		mb_already_synced "$STATE" "$FILE" "$DOC_HASH" "$DESIGN_HASH" && exit 0
		if ! grep -qF -- '<!-- mockingbird:design:begin -->' "$FILE" 2>/dev/null; then
			emit "docs/design/manifest.yaml existiert, aber diese Spec trägt keinen Design-Block. Rufe den Skill carrying-design-through (mockingbird) mit mode=spec und path=$FILE auf. $SEQ_HINT"
		fi
		BLOCK_HASH="$(mb_block_fact "$FILE" design_hash)"; BLOCK_HASH="${BLOCK_HASH#sha256:}"
		if [ "$BLOCK_HASH" != "$DESIGN_HASH" ]; then
			emit "Der Design-Block dieser Spec ist veraltet (Block: ${BLOCK_HASH:-keiner}, aktuell: $DESIGN_HASH). Rufe den Skill carrying-design-through (mockingbird) mit mode=sync und path=$FILE auf. $SEQ_HINT"
		fi
		mb_record_synced "$STATE" "$FILE" "$DOC_HASH" "$DESIGN_HASH" 2>/dev/null || true
		exit 0
		;;

	plan)
		[ -f "$MANIFEST" ] || exit 0
		mb_already_synced "$STATE" "$FILE" "$DOC_HASH" "$DESIGN_HASH" && exit 0
		# The hook stays dumb on purpose: it only asks whether the design was
		# handed on at all. Whether every task carries its own design table is
		# a question for /design-check, which can read the manifest.
		if ! grep -qF -- 'docs/design/manifest.yaml' "$FILE" 2>/dev/null; then
			emit "Dieser Plan gibt das Design nicht weiter: weder Header-Zeile noch Global Constraints nennen docs/design/manifest.yaml. Ohne das erreicht der Entwurf keinen Task-Brief. Rufe den Skill carrying-design-through (mockingbird) mit mode=plan und path=$FILE auf. $SEQ_HINT"
		fi
		mb_record_synced "$STATE" "$FILE" "$DOC_HASH" "$DESIGN_HASH" 2>/dev/null || true
		exit 0
		;;
esac

exit 0
