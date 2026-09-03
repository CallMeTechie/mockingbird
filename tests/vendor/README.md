# Vendored fragments

`superpowers-6.3.0-task-brief.awk` is the exact task-extraction awk program
from `skills/subagent-driven-development/scripts/task-brief` in
[obra/superpowers](https://github.com/obra/superpowers) v6.3.0, copied
verbatim from `/root/.claude/plugins/cache/claude-plugins-official/superpowers/6.3.0/`.
MIT licensed, © 2025 Jesse Vincent.

mockingbird's whole design is built around what survives this exact cut: a
design table placed *inside* a `### Task N` section survives into the task
brief an implementer subagent reads; anything in the plan header or in
`## Global Constraints` does not. `tests/run-plan-propagation-tests.sh` runs
this real program against fixture plans, not a paraphrase of it — a
reimplementation could silently drift from upstream and give a false sense of
safety.

Update this file's content whenever superpowers is upgraded and the
extraction logic changed (diff against the new version's `task-brief`).
