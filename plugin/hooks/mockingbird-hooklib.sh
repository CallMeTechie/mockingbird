# shellcheck shell=bash
# Pure helper functions for the mockingbird PostToolUse hook.
# Sourced by detect-design-context.sh and by tests. No side effects on source.
#
# This file deliberately knows nothing about YAML, about the manifest schema or
# about the design block. It only classifies paths and keeps bookkeeping, so the
# hook stays fast and cannot be broken by a malformed manifest. Everything with
# domain knowledge lives in plugin/lib/ and is never sourced from here.

# Echo "manifest" | "system" | "artboard" | "spec" | "plan" | "" for a path.
# Artboards are matched one level deep only: a nested docs/design/mockups/sub/
# is someone else's directory, not ours, and must not trigger a rewrite.
mb_detect_kind() {
	case "$1" in
		*/docs/design/manifest.yaml)          printf 'manifest' ;;
		*/docs/design/design-system.md)       printf 'system' ;;
		*/docs/design/mockups/*/*)            printf '' ;;
		*/docs/design/mockups/*.html)         printf 'artboard' ;;
		*/docs/design/mockups/*.css)          printf 'artboard' ;;
		*/docs/superpowers/specs/*-design.md) printf 'spec' ;;
		*/docs/superpowers/plans/*.md)        printf 'plan' ;;
		*) printf '' ;;
	esac
}

# Return 0 if the path is safe (contains no control characters). Control chars
# can split grep -F patterns and corrupt the tab-separated state file.
mb_path_ok() {
	case "$1" in
		*[[:cntrl:]]*) return 1 ;;
		*) return 0 ;;
	esac
}

# Canonicalize to a normalized absolute path (resolves ./, ../, trailing slash
# and existing symlinks; does not require the path to exist).
mb_canon_path() {
	realpath -m -- "$1" 2>/dev/null || printf '%s' "$1"
}

# Walk up from the file's directory to a project root (a directory containing
# .git or .claude); fall back to $2.
mb_find_root() {
	local dir
	# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
	dir="$(CDPATH= cd -- "$(dirname -- "$1")" 2>/dev/null && pwd)" || { printf '%s' "$2"; return; }
	while [ -n "$dir" ] && [ "$dir" != "/" ]; do
		if [ -d "$dir/.git" ] || [ -d "$dir/.claude" ]; then
			printf '%s' "$dir"; return
		fi
		dir="$(dirname -- "$dir")"
	done
	printf '%s' "$2"
}

# SHA-256 of a file's contents (empty string if the file or the tool is missing).
mb_hash() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum -- "$1" 2>/dev/null | cut -d' ' -f1
	elif command -v shasum >/dev/null 2>&1; then
		shasum -a 256 -- "$1" 2>/dev/null | cut -d' ' -f1
	else
		printf ''
	fi
}

# State file lines are: <doc_sha256>\t<manifest_sha256>\t<abs-doc-path>
#
# Two hashes, not one. preflight keys its debounce on the document alone, so a
# changed mockup with an unchanged spec produces no nudge at all. Here an entry
# is only clean while BOTH still match, which is what makes drift detection work.

# Return 0 if this exact (doc hash, manifest hash, path) triple is recorded.
# An empty hash returns 1 (fail-open: we would rather nudge once too often).
mb_already_synced() {
	local state="$1" path="$2" dochash="$3" manhash="$4" line
	[ -n "$dochash" ] && [ -n "$manhash" ] || return 1
	[ -f "$state" ] || return 1
	path="$(mb_canon_path "$path")"
	line="$(printf '%s\t%s\t%s' "$dochash" "$manhash" "$path")"
	grep -qFx -- "$line" "$state" 2>/dev/null
}

# Record the triple, atomically replacing any previous entry for the same path
# (prevents unbounded growth and stale hashes surviving a rewrite).
mb_record_synced() {
	local state="$1" path="$2" dochash="$3" manhash="$4" tmp
	mb_path_ok "$path" || return 1
	path="$(mb_canon_path "$path")"
	tmp="$(mktemp "$(dirname -- "$state")/.mockingbird-tmp.XXXXXX")" || return 1
	if [ -f "$state" ]; then
		_MB_PATH="$path" awk -F'\t' '$3 != ENVIRON["_MB_PATH"]' "$state" > "$tmp"
	fi
	printf '%s\t%s\t%s\n' "$dochash" "$manhash" "$path" >> "$tmp"
	mv -- "$tmp" "$state"
}

# List the documents whose recorded manifest hash differs from <manhash>, one
# absolute path per line. This is the drift detector: it answers "the manifest
# just changed — which documents now describe an older design?" without anyone
# having to touch those documents.
mb_stale_docs() {
	local state="$1" manhash="$2"
	[ -f "$state" ] || return 0
	_MB_MANHASH="$manhash" awk -F'\t' '$2 != ENVIRON["_MB_MANHASH"] { print $3 }' "$state" 2>/dev/null
}

# Lock content is: <unix-ts>\t<session-id>
# The session id is what makes the lock self-healing without a SessionStart
# hook: a lock left by a different session is orphaned by definition, no matter
# how fresh it looks. If the harness does not supply a session id the field is
# empty on both sides and the TTL alone decides — the lock still works, it just
# heals more slowly.
mb_write_lock() {
	printf '%s\t%s\n' "$(date +%s)" "${2:-}" > "$1"
}

# Return 0 if a lock is held that this caller must respect.
# Stale threshold default 900s.
mb_is_locked() {
	local lock="$1" session="${2:-}" threshold="${3:-900}" now line ts owner age
	[ -f "$lock" ] || return 1
	now="$(date +%s 2>/dev/null)" || return 1
	line="$(head -n1 -- "$lock" 2>/dev/null)"
	ts="${line%%$'\t'*}"
	owner=""
	case "$line" in *$'\t'*) owner="${line#*$'\t'}" ;; esac
	case "$ts" in ''|*[!0-9]*) return 1 ;; esac
	age=$(( now - ts ))
	# A future timestamp (clock jump) counts as locked, never as unlocked.
	[ "$age" -lt "$threshold" ] || return 1
	# Orphan check: only decidable when both sides name a session.
	if [ -n "$owner" ] && [ -n "$session" ] && [ "$owner" != "$session" ]; then
		return 1
	fi
	return 0
}

# Remove a lock we have determined to be orphaned. Never removes a live lock.
mb_clear_orphaned_lock() {
	local lock="$1" session="${2:-}"
	[ -f "$lock" ] || return 0
	mb_is_locked "$lock" "$session" && return 0
	rm -f -- "$lock"
}

# Hash of the whole design directory, not just manifest.yaml: an edited artboard
# or an edited design-system.md is design drift too, and keying only on the
# manifest would miss it silently. Relative paths are hashed, never absolute
# ones, so the value is identical in every clone of the repo.
# Empty string if there is no design directory.
mb_design_hash() {
	local root="$1" dir="$1/docs/design"
	[ -d "$dir" ] || { printf ''; return; }
	{
		find "$dir" -type f \
			\( -name '*.yaml' -o -name '*.yml' -o -name '*.md' -o -name '*.html' -o -name '*.css' \) \
			-print 2>/dev/null |
		while IFS= read -r f; do
			printf '%s %s\n' "${f#"$root"/}" "$(mb_hash "$f")"
		done | LC_ALL=C sort
	} | sha256sum 2>/dev/null | cut -d' ' -f1
}

# Read one key=value fact from the design block in <file>, fence-aware: only
# the "<!-- design: ... -->" comment BETWEEN the mockingbird markers counts,
# and markers inside fenced code blocks are ignored. Without this the hook's
# earlier plain grep read the first "design_hash=" in the file -- which in a
# spec that documents the format is the example, not the block -- and raised a
# false "veraltet" nudge. A small duplication of the block library's awk on
# purpose: the hook must never source plugin/lib/ (that would drag the
# manifest parser into every Write/Edit), so it carries its own copy.
# Empty output when there is no block or the key is absent.
mb_block_fact() {
	awk -v key="$2" '
		{ line = $0; sub(/[[:space:]]+$/, "", line); sub(/^[[:space:]]+/, "", line) }
		line ~ /^(```|~~~)/ { fence = !fence; next }
		fence { next }
		line == "<!-- mockingbird:design:begin -->" { inblock = 1; next }
		line == "<!-- mockingbird:design:end -->"   { inblock = 0; next }
		inblock && /<!-- design:/ { infacts = 1 }
		inblock && infacts {
			n = split($0, tok, /[[:space:]]+/)
			for (i = 1; i <= n; i++) if (index(tok[i], key "=") == 1) { print substr(tok[i], length(key) + 2); exit }
			if ($0 ~ /-->/) infacts = 0
		}
	' "$1" 2>/dev/null
}
