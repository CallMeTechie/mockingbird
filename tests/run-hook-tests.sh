#!/usr/bin/env bash
# Hook layer: path detection, project root, state bookkeeping, locking,
# and the end-to-end stdin -> stdout behaviour of detect-design-context.sh.
set -u
# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(dirname -- "$HERE")"
. "$HERE/_helper.sh"
. "$ROOT/plugin/hooks/mockingbird-hooklib.sh"

sandbox

echo "== mb_detect_kind =="
check "manifest"        "manifest" "$(mb_detect_kind /p/docs/design/manifest.yaml)"
check "design system"   "system"   "$(mb_detect_kind /p/docs/design/design-system.md)"
check "artboard html"   "artboard" "$(mb_detect_kind /p/docs/design/mockups/ui-orders.html)"
check "artboard css"    "artboard" "$(mb_detect_kind /p/docs/design/mockups/tokens.css)"
check "spec"            "spec"     "$(mb_detect_kind /p/docs/superpowers/specs/2026-09-03-x-design.md)"
check "plan"            "plan"     "$(mb_detect_kind /p/docs/superpowers/plans/2026-09-03-x.md)"
# Negatives: a near miss must be silence, not a wrong classification.
check "wrong extension" ""         "$(mb_detect_kind /p/docs/design/manifest.yml)"
check "spec without -design" ""        "$(mb_detect_kind /p/docs/superpowers/specs/notes.md)"
check "nested artboard" ""         "$(mb_detect_kind /p/docs/design/mockups/sub/x.html)"
check "unrelated file"  ""         "$(mb_detect_kind /p/src/index.ts)"
check "design dir other" ""        "$(mb_detect_kind /p/docs/design/notes.md)"

echo "== mb_path_ok =="
check_rc "clean path accepted" 0 mb_path_ok "/p/docs/design/manifest.yaml"
check_rc "control char rejected" 1 mb_path_ok "$(printf '/p/bad\tpath.md')"

echo "== mb_canon_path =="
check "dot segments" "/p/b.md" "$(mb_canon_path /p/./a/../b.md)"

echo "== mb_find_root =="
mkdir -p "$SANDBOX/proj/.git" "$SANDBOX/proj/docs/design"
: > "$SANDBOX/proj/docs/design/manifest.yaml"
check "finds .git root" "$SANDBOX/proj" "$(mb_find_root "$SANDBOX/proj/docs/design/manifest.yaml" /fallback)"
mkdir -p "$SANDBOX/proj2/.claude/x" "$SANDBOX/proj2/docs"
: > "$SANDBOX/proj2/docs/a.md"
check "finds .claude root" "$SANDBOX/proj2" "$(mb_find_root "$SANDBOX/proj2/docs/a.md" /fallback)"
check "falls back to cwd" "/fallback" "$(mb_find_root "$SANDBOX/nowhere/a.md" /fallback)"

echo "== mb_hash =="
printf 'hello\n' > "$SANDBOX/f1"
H1="$(mb_hash "$SANDBOX/f1")"
check "hash is 64 hex" "64" "${#H1}"
check "missing file -> empty" "" "$(mb_hash "$SANDBOX/nope")"

echo "== state: mb_already_synced / mb_record_synced =="
STATE="$SANDBOX/.mockingbird-synced"
DOC="$SANDBOX/proj/docs/superpowers/specs/a-design.md"
mkdir -p "$(dirname -- "$DOC")"; printf 'doc\n' > "$DOC"
DH="$(mb_hash "$DOC")"; MH="deadbeef"
check_rc "unknown doc is not synced" 1 mb_already_synced "$STATE" "$DOC" "$DH" "$MH"
mb_record_synced "$STATE" "$DOC" "$DH" "$MH"
check_rc "recorded doc is synced" 0 mb_already_synced "$STATE" "$DOC" "$DH" "$MH"
# The whole point of the two-hash state: a changed manifest invalidates the
# entry even though the document itself did not change. preflight cannot see this.
check_rc "changed manifest invalidates" 1 mb_already_synced "$STATE" "$DOC" "$DH" "cafebabe"
check_rc "changed doc invalidates" 1 mb_already_synced "$STATE" "$DOC" "otherhash" "$MH"
check_rc "empty doc hash fails open" 1 mb_already_synced "$STATE" "$DOC" "" "$MH"
# Re-recording must replace, not append, or the state file grows without bound.
mb_record_synced "$STATE" "$DOC" "newdochash" "$MH"
check "one line per doc" "1" "$(wc -l < "$STATE" | tr -d ' ')"
check_rc "old entry gone" 1 mb_already_synced "$STATE" "$DOC" "$DH" "$MH"
# A path that differs only by ./ must resolve to the same entry.
check_rc "canonicalized lookup" 0 mb_already_synced "$STATE" "$SANDBOX/proj/./docs/superpowers/specs/a-design.md" "newdochash" "$MH"
check_rc "control char path refused" 1 mb_record_synced "$STATE" "$(printf '/p/b\tad.md')" "h" "$MH"

echo "== state: mb_stale_docs =="
DOC2="$SANDBOX/proj/docs/superpowers/specs/b-design.md"
printf 'doc2\n' > "$DOC2"
mb_record_synced "$STATE" "$DOC2" "$(mb_hash "$DOC2")" "cafebabe"
check "stale against MH" "$DOC2" "$(mb_stale_docs "$STATE" "$MH")"
check "current doc not listed" "" "$(mb_stale_docs "$STATE" "$MH" | grep -F "a-design" || true)"
check "all stale for new MH" "2" "$(mb_stale_docs "$STATE" "0000" | wc -l | tr -d ' ')"
check "missing state -> empty" "" "$(mb_stale_docs "$SANDBOX/nope" "$MH")"

echo "== lock =="
LOCK="$SANDBOX/.mockingbird-running"
check_rc "no lock file -> unlocked" 1 mb_is_locked "$LOCK" "sess-a"
mb_write_lock "$LOCK" "sess-a"
check_rc "fresh lock, same session -> locked" 0 mb_is_locked "$LOCK" "sess-a"
# Lock self-healing: a lock from another session is orphaned by definition.
check_rc "fresh lock, other session -> not locked" 1 mb_is_locked "$LOCK" "sess-b"
printf '%s\tsess-a\n' "$(( $(date +%s) - 4000 ))" > "$LOCK"
check_rc "stale lock -> not locked" 1 mb_is_locked "$LOCK" "sess-a"
printf 'garbage\n' > "$LOCK"
check_rc "garbage lock -> not locked" 1 mb_is_locked "$LOCK" "sess-a"
printf '%s\tsess-a\n' "$(( $(date +%s) + 4000 ))" > "$LOCK"
check_rc "future timestamp -> locked" 0 mb_is_locked "$LOCK" "sess-a"
# Empty session id must fall back to pure TTL, never to "always unlocked":
# if session_id turns out not to be in the payload, the lock still works.
mb_write_lock "$LOCK" ""
check_rc "no session id -> TTL only, locked" 0 mb_is_locked "$LOCK" ""
check_rc "no session id in lock, caller has one -> locked" 0 mb_is_locked "$LOCK" "sess-a"

echo "== mb_design_hash =="
PROJ="$SANDBOX/dh"; mkdir -p "$PROJ/docs/design/mockups" "$PROJ/.git"
printf 'schema: mockingbird/1\n' > "$PROJ/docs/design/manifest.yaml"
printf '# system\n'              > "$PROJ/docs/design/design-system.md"
printf '<html></html>\n'         > "$PROJ/docs/design/mockups/a.html"
DH1="$(mb_design_hash "$PROJ")"
check "design hash is 64 hex" "64" "${#DH1}"
check "stable across calls" "$DH1" "$(mb_design_hash "$PROJ")"
# An edited artboard must move the hash — keying only on manifest.yaml would not.
printf '<html>changed</html>\n' > "$PROJ/docs/design/mockups/a.html"
DH2="$(mb_design_hash "$PROJ")"
check_rc "artboard edit changes hash" 1 test "$DH1" = "$DH2"
printf '# system v2\n' > "$PROJ/docs/design/design-system.md"
check_rc "system edit changes hash" 1 test "$DH2" = "$(mb_design_hash "$PROJ")"
# Same content in a different clone location must hash identically.
PROJ2="$SANDBOX/dh-elsewhere"; mkdir -p "$PROJ2"
cp -r "$PROJ/docs" "$PROJ2/docs"
check "identical in another clone" "$(mb_design_hash "$PROJ")" "$(mb_design_hash "$PROJ2")"
check "no design dir -> empty" "" "$(mb_design_hash "$SANDBOX/nowhere")"

echo "== mb_block_fact: fence-aware fact extraction =="
BF="$SANDBOX/bf.md"
{
	printf '# Spec\n\nExample of the format:\n\n```markdown\n<!-- mockingbird:design:begin -->\n<!-- design: design_hash=sha256:0000 adapter=tui -->\n<!-- mockingbird:design:end -->\n```\n\n'
	printf '<!-- mockingbird:design:begin -->\n<!-- design: manifest=docs/design/manifest.yaml design_rev=3\n     design_hash=sha256:abcd adapter=web -->\n<!-- mockingbird:design:end -->\n'
} > "$BF"
check "reads the real block, not the fenced example" "sha256:abcd" "$(mb_block_fact "$BF" design_hash)"
check "reads a key on a continuation line" "web" "$(mb_block_fact "$BF" adapter)"
check "reads a key on the first facts line" "3" "$(mb_block_fact "$BF" design_rev)"
check "absent key -> empty" "" "$(mb_block_fact "$BF" nope)"
printf '# no block\n<!-- design: design_hash=sha256:ffff -->\n' > "$BF"
check "facts comment outside any block is ignored" "" "$(mb_block_fact "$BF" design_hash)"

echo "== detect-design-context.sh end to end =="
HOOK="$ROOT/plugin/hooks/detect-design-context.sh"
P="$SANDBOX/e2e"
mkdir -p "$P/.git" "$P/.claude" "$P/docs/design/mockups" \
         "$P/docs/superpowers/specs" "$P/docs/superpowers/plans"
SPEC="$P/docs/superpowers/specs/2026-09-03-orders-design.md"
PLAN="$P/docs/superpowers/plans/2026-09-03-orders.md"
MAN="$P/docs/design/manifest.yaml"

# run_hook <file> [session] -> stdout of the hook; asserts exit 0 separately.
run_hook() {
	jq -n --arg f "$1" --arg c "$P" --arg s "${2:-sess-1}" \
		'{tool_name:"Write",tool_input:{file_path:$f},cwd:$c,session_id:$s}' | bash "$HOOK"
}
ctx() { printf '%s' "$1" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null; }

printf 'nothing to see\n' > "$P/src.ts"
check "unrelated path is silent" "" "$(run_hook "$P/src.ts")"
check_rc "unrelated path exits 0" 0 bash -c 'jq -n "{tool_name:\"Write\",tool_input:{}}" | bash "$0"' "$HOOK"

# --- spec written while no design exists at all -------------------------------
printf '# Orders\n\nBackend only, queues and retries.\n' > "$SPEC"
check "backend spec is silent" "" "$(run_hook "$SPEC")"
printf '# Orders\n\nDas Dashboard zeigt eine Ansicht der offenen Bestellungen.\n' > "$SPEC"
OUT="$(run_hook "$SPEC")"
case "$(ctx "$OUT")" in *"/design"*) R=ok ;; *) R="$OUT" ;; esac
check "UI spec without design nudges /design" "ok" "$R"
check "same spec version stays silent" "" "$(run_hook "$SPEC")"

# --- manifest exists ----------------------------------------------------------
printf 'schema: mockingbird/1\nrevision: 1\n' > "$MAN"
printf '# design system\n' > "$P/docs/design/design-system.md"
printf '<html></html>\n' > "$P/docs/design/mockups/ui-orders.html"
DH="$(mb_design_hash "$P")"

OUT="$(run_hook "$SPEC")"
case "$(ctx "$OUT")" in *"keinen Design-Block"*) R=ok ;; *) R="$OUT" ;; esac
check "spec without block nudges" "ok" "$R"

{
	printf '# Orders\n\nDas Dashboard zeigt eine Ansicht.\n\n'
	printf '<!-- mockingbird:design:begin -->\n'
	printf '<!-- design: manifest=docs/design/manifest.yaml design_rev=1 design_hash=sha256:%s -->\n' "$DH"
	printf '<!-- mockingbird:design:end -->\n'
} > "$SPEC"
check "spec with current block is silent" "" "$(run_hook "$SPEC")"
check_rc "and got recorded in state" 0 mb_already_synced "$P/.claude/.mockingbird-synced" "$SPEC" "$(mb_hash "$SPEC")" "$DH"

sed -i 's/design_hash=sha256:[0-9a-f]*/design_hash=sha256:0000/' "$SPEC"
OUT="$(run_hook "$SPEC")"
case "$(ctx "$OUT")" in *"veraltet"*) R=ok ;; *) R="$OUT" ;; esac
check "stale block hash nudges" "ok" "$R"

# --- drift: the design actually changes ---------------------------------------
# The spec was recorded against the old design hash in the case above. Editing
# an artboard moves the design hash, so writing the manifest must now name that
# spec as outdated — without anyone having touched the spec.
printf '<html>v2</html>\n' > "$P/docs/design/mockups/ui-orders.html"
OUT="$(run_hook "$MAN")"
case "$(ctx "$OUT")" in *"orders-design.md"*) R=ok ;; *) R="$OUT" ;; esac
check "manifest write lists the stale spec" "ok" "$R"

# --- plan ---------------------------------------------------------------------
printf '# Orders Implementation Plan\n\n**Spec:** `%s`\n' "$SPEC" > "$PLAN"
OUT="$(run_hook "$PLAN")"
case "$(ctx "$OUT")" in *"gibt das Design nicht weiter"*) R=ok ;; *) R="$OUT" ;; esac
check "plan without design reference nudges" "ok" "$R"
printf '\n**Design:** `docs/design/manifest.yaml` (rev 1)\n' >> "$PLAN"
check "plan with design reference is silent" "" "$(run_hook "$PLAN")"

# --- suppression --------------------------------------------------------------
sed -i 's/design_hash=sha256:[0-9a-f]*/design_hash=sha256:1111/' "$SPEC"
mb_write_lock "$P/.claude/.mockingbird-running" "sess-1"
check "own fresh lock silences" "" "$(run_hook "$SPEC" sess-1)"
# A lock from another session is orphaned and must not silence us.
OUT="$(run_hook "$SPEC" sess-2)"
check_rc "other session is not silenced" 1 test -z "$OUT"
rm -f "$P/.claude/.mockingbird-running"
mb_write_lock "$P/.claude/.preflight-running" ""
check "preflight lock silences" "" "$(run_hook "$SPEC")"
rm -f "$P/.claude/.preflight-running"
: > "$P/.claude/.mockingbird-off"
check "opt-out silences" "" "$(run_hook "$SPEC")"
rm -f "$P/.claude/.mockingbird-off"

# Whatever happens, the hook must never fail a tool call.
for f in "$SPEC" "$PLAN" "$MAN" "$P/src.ts" "$P/nonexistent-design.md"; do
	check_rc "exit 0 for $(basename "$f")" 0 run_hook "$f"
done

summary "run-hook-tests"
