#!/usr/bin/env bash
# Structural checks over the whole plugin tree: agent/command frontmatter,
# the write-tools restriction (preflight's own test caught a real bug here
# once — "exactly one file under agents/ may carry write tools"), the ban on
# AskUserQuestion in any agent (fleet-manager lost a release to exactly this:
# subagents don't have AskUserQuestion), manifest well-formedness, and no
# state writes under the plugin's own install directory.
set -u
# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(dirname -- "$HERE")"
. "$HERE/_helper.sh"

echo "== agents: frontmatter and write-tool restriction =="
WRITERS=0
for f in "$ROOT"/plugin/agents/*.md; do
	name="$(basename "$f" .md)"
	check "agent $name has a name: field matching its filename" "1" "$(grep -c "^name: $name\$" "$f")"
	check "agent $name has a tools: field" "1" "$(grep -c '^tools:' "$f")"
	check "agent $name declares no AskUserQuestion" "0" "$(grep -c 'AskUserQuestion' "$f")"
	if grep -q '^tools:.*\(Write\|Edit\)' "$f"; then
		WRITERS=$((WRITERS + 1))
		check "writer agent $name is editor or artboard-writer" "1" "$(case "$name" in editor|artboard-writer) echo 1 ;; *) echo 0 ;; esac)"
	fi
done
check "exactly two agents carry write tools" "2" "$WRITERS"

echo "== commands: frontmatter =="
for f in "$ROOT"/plugin/commands/*.md; do
	name="$(basename "$f" .md)"
	check "command $name has a description:" "1" "$(grep -c '^description:' "$f")"
done
check "/design has AskUserQuestion in allowed-tools" "1" "$(grep -c 'AskUserQuestion' "$ROOT/plugin/commands/design.md")"

echo "== skills: frontmatter =="
for f in "$ROOT"/plugin/skills/*/SKILL.md; do
	dir="$(basename "$(dirname "$f")")"
	check "skill $dir: name matches its directory" "1" "$(grep -c "^name: $dir\$" "$f")"
	check "skill $dir: description starts with 'Use'" "1" "$(grep -c '^description: Use' "$f")"
done

echo "== manifests =="
check "plugin.json: repository is a string" "\"string\"" "$(python3 -c "import json; print(type(json.load(open('$ROOT/plugin/.claude-plugin/plugin.json'))['repository']).__name__ == 'str' and '\"string\"' or 'NOT-A-STRING')" 2>/dev/null)"
check "plugin.json and marketplace.json versions match" "1" "$(python3 -c "
import json
p = json.load(open('$ROOT/plugin/.claude-plugin/plugin.json'))['version']
m = json.load(open('$ROOT/.claude-plugin/marketplace.json'))['plugins'][0]['version']
print(1 if p == m else 0)
")"
check "marketplace.json source points at ./plugin" "1" "$(python3 -c "
import json
print(1 if json.load(open('$ROOT/.claude-plugin/marketplace.json'))['plugins'][0]['source'] == './plugin' else 0)
")"

echo "== no writes to \$CLAUDE_PLUGIN_ROOT =="
check "no script writes under CLAUDE_PLUGIN_ROOT" "0" "$(grep -rlE '>[^&]*"\$CLAUDE_PLUGIN_ROOT|mkdir[^"]*"\$CLAUDE_PLUGIN_ROOT' "$ROOT/plugin" 2>/dev/null | wc -l | tr -d ' ')"

summary "run-wellformed-tests"
