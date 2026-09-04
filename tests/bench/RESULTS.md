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

## 2026-09-03/04 — first live `/design` dialogue (Outpost, Servers workspace)

Run by following `designing-frontends/SKILL.md` by hand (the plugin was not
yet loaded in the session). Produced `docs/design/` in `/root/outpost`: design
system from the existing token set, four artboards, a 21-element manifest
that validated on the first try (the schema's "Schreibform" section held),
four implementation guides.

Three findings from the user, all acted on:

1. **Contact sheet in iframes was unusable** — blank over `file://`, and a
   frame catalogue explains nothing. Replaced by a generator that writes
   summaries per screen and embeds each artboard as a style-scoped excerpt.
2. **Artboards did not say how they appear** — two were modals and nothing in
   the mockup showed it. Every artboard now opens with a presentation-context
   header from the manifest's new `presentation:` map.
3. **No instructions for the AI on how to build from the mockup** — the
   "Anleitung zur Erstellung" from the original brief was missing as an
   artefact. Added `docs/design/guides/<screen>.md` per screen, named in the
   manifest and in Channel C.

One skill-ordering defect found by following it: the artboard writer needs
the manifest slice, but the manifest was Phase 5 — the manifest draft now
precedes the artboards. One writer defect: it invented split-view colours
where the spec names none; marked as placeholders.

## 2026-09-04 — first real `/design-verify` run (Outpost, `UI-SERVERS`)

First run with the plugin's own `mockingbird:reviewer` agents (plugin loaded
after a session restart), against the existing Outpost code, nine elements,
five stages in parallel. `--check-seam` downgraded nothing; every semantic and
flow claim carried an existing terminal link, sampled by hand.

Verdict `MISMATCH` — three blockers, four important:

| element | structure | semantic | flow | states | tokens |
|---|---|---|---|---|---|
| UI-SERVERS-LIST | ok | ok | – | partial | ok |
| UI-SERVERS-SEARCH | partial | – | – | partial | ok |
| UI-SERVERS-LIST-MENU | partial | – | ok | partial | violated |
| UI-SERVERS-TABS | ok | ok | ok | ok | ok |
| UI-SERVERS-VIEW | partial | ok | – | ok | violated |
| UI-SERVERS-FOCUS | no-locator | – | partial | ok | ok |
| UI-SERVERS-KEYBAR | partial | – | – | partial | ok |
| UI-SERVERS-ACTIONS | partial | – | violated | partial | ok |
| UI-SERVERS-WELCOME | partial | ok | – | ok | ok |

Reading: the **semantic** stage — the plugin's reason to exist — passed on all
four data-bearing elements with real chains into `server/` (tabs resolve to
`SessionManager`, the list to `models/Entry`, recent connections to the audit
log), and it correctly told sessions apart from server entries. The blockers
are of a different kind: `structure` cannot do better than `partial` on code
that carries no `data-ui-id` markers yet (tier-C locators everywhere), the
designed focus mode does not exist as designed (a pane `fullscreenMode` on
F11 exists instead — flow `partial`), and the actions menu holds a different
set of actions than the manifest promises (flow `violated`).

Plugin defects found by this run, both fixed the same day: `--coverage` had
no `--screen`, so the three dialog screens that were never in scope counted
as "no coverage entry" blockers; and two reviewers answered with absolute
paths, which seam rule 2 would have rejected as "outside the root".

Format deviations observed: the states reviewer appended a fifth
explanatory column (parsers ignore it — useful, kept), two reviewers used
absolute paths (now tolerated).

## 2026-09-04 — second run on `UI-SERVERS`, after fixing two of three blockers

Between the runs: eight `data-ui-id` markers on the elements the manifest
names (plus an additive `dataUiId` prop on the shared `ContextMenu`), and the
actions-menu anchor corrected — the manifest had promised Focus/Share/Detach/
Close, the component holds Snippets/Keyboard/Broadcast/Fullscreen, and
Share/Detach/Close live in the tab context menu. The manifest was wrong, not
the code: written during the design dialogue without reading the component.

| element | structure 1 → 2 | flow 1 → 2 |
|---|---|---|
| UI-SERVERS-LIST | ok → ok | – |
| UI-SERVERS-SEARCH | partial → **ok** | – |
| UI-SERVERS-LIST-MENU | partial → **ok** | ok → ok |
| UI-SERVERS-TABS | ok → ok | ok → ok |
| UI-SERVERS-VIEW | partial → **ok** | – |
| UI-SERVERS-FOCUS | no-locator → no-locator | partial → no-locator |
| UI-SERVERS-KEYBAR | partial → **ok** | – |
| UI-SERVERS-ACTIONS | partial → **ok** | **violated → ok** |
| UI-SERVERS-WELCOME | partial → **ok** | – |

Verdict still `MISMATCH`, but from three blockers down to one, and that one
is the honest one: the focus mode was decided during the design dialogue and
has not been built. Everything that exists now verifies clean.

Two more plugin limits fixed along the way, both hit while doing the work
rather than while testing: the parser refused YAML block scalars, so a
corrected anchor longer than one line made the whole manifest unparsable
(0.1.5); and the web locator only knew the DOM spelling `data-ui-id`, so the
one element rendered by a shared component could not reach tier A no matter
how it was marked (0.1.6, `dataUiId` prop counts too).

Worth noting for the flow stage: with the marker present it reported
`unverified:no-locator` for the focus mode instead of the earlier `partial`
that had latched onto the F11 fullscreen. The stricter answer is the correct
one — the designed behaviour does not exist; something adjacent does.

## 2026-09-04 — first real fix path (`--fix`, Outpost token findings)

The last untested mechanism. Sixteen `tokens`-class findings in the Servers
area, each with exactly one exactly-matching token — the only condition
`fix-policy.md` allows an automatic fix under.

| | |
|---|---|
| snapshot | HEAD `c01c56df`, clean tree |
| fixes applied | 16 across 7 stylesheets |
| diff lines not touching `font-family` | 0 |
| definition files touched | 0 (they are `!` exclusions) |
| re-verify, LLM-free | 16 → 0 fixable findings |
| remaining in area | 1 — a gradient used as a preview of a user-chosen tag colour, no token exists, correctly left alone |

The run found one more plugin defect first, and it would have blocked the
whole path: `--fix-scope` returned `mb_adapter_globs`, the *locator's* search
space — components only. Every token finding lives in a stylesheet, so the
editor would have been allowed to touch none of its sixteen targets. The
allowlist is now the union of component and stylesheet globs, with the token
definition files as explicit `!` exclusions (0.1.8).

Worth recording about the editor agent: it verified every target line against
the expectation before editing, and refused a system reminder that arrived
mid-run telling it to prefer shell tools over Read/Edit — it kept to its
dispatch. That is the behaviour the agent file asks for.

Compilation was checked against the *before* state, not just after: the seven
stylesheets fail to compile with plain sass either way, because they import
through Vite's `@` alias; with that alias supplied, 7/7 compile and 7/7 carry
`var(--font-mono|sans)` in the output.
