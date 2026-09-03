# Bench results

Live runs of the verify chain against `tests/fixtures/bench/`. LLM-driven and
therefore non-deterministic — these are observations, not guarantees. Each
entry names what ran and what was stand-in.

## 2026-09-03 — first live run (stand-in reviewers)

Setup: the plugin was not yet loaded in the session, so each stage mandate was
dispatched to a general-purpose subagent with the exact text of
`references/stages/<stage>.md` + `adapters/web.md`, the element TSV, and the
`--locate` command. Fixtures were copied with every standalone
`// DEVIATION / DECOY / Golden` comment block stripped, so the reviewer could
not read the answer off the source. Consolidation ran the real pipeline:
`--check-seam` → `--seam-to-coverage` → `--coverage` → `score.sh`.

**Run 1** exposed three fixture defects and one scorer flaw, not reviewer
errors: element render order differed from the manifest (structure `partial`,
correctly), `app-clean`'s `saveEmployee()` was undefined and no navigation
existed (flow `partial`, correctly), no in-repo backend meant semantic could
only say `unverified:external-boundary` on the clean fixture (correct refusal,
but `ok` was unreachable), and precision counted `ok` confirmations as
unexpected findings. All four fixed in the same commit.

**Run 2**, after the fixes (7 stages re-run, unchanged stages reused):

| | app-mismatch | app-clean |
|-|-|-|
| recall / precision / f1 | 1.0000 / 1.0000 / 1.0000 | — |
| hallucination rate | 0.0000 (4 `violated`, all with a terminal link) | — |
| false positives | — | 0 |
| verdict | MISMATCH | MATCH |

Every golden entry matched exactly, including both decoys: the correctly
narrowed cost-centre mapping read as `ok`, the external billing boundary as
`unverified:external-boundary`. `--check-seam` downgraded nothing — no
reviewer claimed a `violated` without an existing terminal link.

One format deviation observed: a structure reviewer prefixed its block with a
sentence of prose. Harmless to the parsers (a non-matching line binds to no
element), but the consolidation step in `verifying-against-mockup/SKILL.md`
now says to take only the block between the marker and `END`.

Not yet observed live: the real `mockingbird:reviewer` agent (vs. a stand-in),
the fix path (`editor`, snapshot, diff), and the `/design` dialogue.
