# Changelog

All notable changes to this project are documented in this file.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.8] - 2026-09-04

### Fixed

- `--fix-scope` returns the union of component globs and stylesheet globs, with the token definition files as `!` exclusions. Giving `mb_adapter_globs` both the locator and the allowlist role blocked every token fix — the first real `--fix` run on Outpost had 16 findings, all in `.sass`, none of them editable. 439 checks.

## [0.1.7] - 2026-09-04

### Added

- `/design-check` reports run state under `<project>/.claude/` that git tracks — it dirties the working tree on every run and travels to other machines as if it were a fact about them. Happened on Outpost via a broad `git add -A`. 435 checks.

## [0.1.6] - 2026-09-04

### Added

- The web locator accepts the React prop spelling `dataUiId="X"` as tier A alongside the DOM attribute `data-ui-id="X"` — needed whenever a shared component renders the element and the marker has to be passed through (Outpost's ContextMenu). 433 checks.

## [0.1.5] - 2026-09-04

### Added

- The manifest parser folds YAML block scalars (`>`, `|`) into one line. The one-line-only subset refused every anchor text longer than a line — which is most good anchor texts; found writing Outpost's own manifest. 430 checks.

## [0.1.4] - 2026-09-04

### Added

- Every command accepts `--root DIR`, so a project can be worked on from a session started elsewhere — needed to resume a long session in one directory while verifying a project in another.

## [0.1.3] - 2026-09-04

### Added

- `mb-design-check.sh` checks the artboards' token mirror (`tokens_css`) against the real definitions (`token_definitions`): a token only in the mirror, a token missing from the mirror, or a value that drifted on a single-defined token is a finding. Themed tokens are name-checked. Found on Outpost: the artboards were drawn against a mirror, and nothing had ever compared the two.

## [0.1.2] - 2026-09-04

### Added

- `--tokens` resolves `font-family` findings to a *family* token (`--font-mono`, `--font-sans`), never to a size-bearing `font` shorthand — replacing `font-family: monospace` with `--type-mono` would change size and weight. 415 checks.

## [0.1.1] - 2026-09-04

### Added

- Initial scaffold: marketplace and plugin manifests, MIT license, CI workflow
  (shellcheck + full test suite on every push/PR, tag-and-release on a
  `plugin.json` version bump on `main`).
- Hook layer: path detection for design artefacts/specs/plans, two-hash drift
  state (manifest *and* whole `docs/design/` directory — an edited artboard
  with an unchanged spec is still detected as drift, unlike a debounce keyed
  on the document alone), session-aware self-healing locking, silent
  coexistence with preflight's own hook on the same write.
- Design marker block: placement above preflight's security block, idempotent
  rendering (a byte-identical re-render writes nothing, which is what breaks
  the sync/nudge loop with preflight), fence-aware marker detection.
- Manifest layer: a strict-subset YAML parser (used whenever `yq` is absent,
  which is the common case) normalizing `manifest.yaml` to a flat TSV, plus
  schema and semantic validation (ID grammar, required semantic anchors,
  default-state requirement, deferred/skip reason requirements).
- `carrying-design-through` skill: the four channels a design has to travel
  through to survive plan decomposition (plan header, Global Constraints, a
  per-task design table, a `DESIGN-COVERAGE` block) — proven, not asserted,
  against the real vendored superpowers 6.3.0 `task-brief` cut.
- Deterministic verify core: the four-function adapter contract (`web`
  implemented fully, `tui`/`desktop`/`mobile` documented as capability-only
  stubs so an unimplemented adapter can never produce a silent match), four
  anti-hallucination seam rules and nine coverage/verdict rules enforced in
  bash rather than in a prompt, wired together by `mockingbird-scope.sh`.
- `verifying-against-mockup` skill: the semantic plausibility chain — the
  reason this plugin exists — checking not just that a UI element exists but
  that its data binding actually matches what its label promises (`render ->
  binding -> source -> handler -> terminal`, four judgement classes, a closed
  vocabulary for "cannot verify", never a guess).
- `designing-frontends` skill: the dialogue that produces `docs/design/`
  (design system, HTML artboards, `manifest.yaml`) in the first place —
  reference intake, archetype fallback, an approval gate before anything is
  written into a spec.
- Commands: `/design`, `/design-spec`, `/design-sync`, `/design-split`,
  `/design-check`, `/design-verify`, `/mockingbird-bench`.
- A bench (`tests/fixtures/bench/`) with every planted deviation class from
  the design spec plus two deliberate decoys (a correctly-narrowed mapping
  that must not be flagged, a genuine external service boundary that must
  read as "cannot verify" rather than "violated"), and a locale-independent
  scorer (`tests/bench/score.sh`).
- `mb-design-check.sh`: the split invariants and per-task `**Design:**`
  coverage as a script, not prose; `--seam-to-coverage` bridging the seam
  check to the verdict without a hand-off to judgement; `uses:` and
  `allocations:` parsed so consumed elements and per-spec screens are derived
  instead of supplied; fence-aware fact reading in the hook; the parser's
  accepted subset spelled out in the schema document and the `/design` skill.
- From the first live `/design` dialogue (Outpost, 2026-09-03/04): the contact
  sheet is now generated (`mb-render-index.sh`) — summaries, anchors, states
  and the artboard itself as a style-scoped inline excerpt, never an
  `<iframe>` (blank over `file://`, explains nothing); every artboard opens
  with a presentation-context header (kind, appears over, trigger, size,
  dismiss, keyboard — a dialog that doesn't say it is a dialog is
  incomplete); and the implementation guide `docs/design/guides/<screen>.md`
  becomes a first-class artefact — explicit instructions to the AI on how a
  mockup becomes production code — named in the manifest (`guide:`), carried
  in Channel C, and checked by `mb-design-check.sh`.
- The tokens stage now reads css/sass/scss/less and inline `style=`
  attributes, not `*.css` alone — found on Outpost, where every stylesheet
  is Sass and a css-only scan saw nothing. Manifest keys `token_definitions:`
  (the project's real token files, never flagged) and `source_roots:`
  (monorepo: scan only these directories). Noise cut from 1740 to 67 real
  findings on Outpost by not flagging px values, `var(--x, #hex)` fallbacks,
  `font-family: inherit|var()`, or `@font-face` definition files.
- Plugin rule, in every skill and the README: a fixable plugin limit found
  during a run is fixed in the plugin (code, test, commit) — never written
  into the user's project as a "known gap"; ask only when the fix touches a
  decision of theirs.
- `--tokens` names the matching token per finding (`file:line:<token|ambiguous:a|b|->:content`), built from `tokens_css` + `token_definitions:` — the input fix-policy's "exactly one exact token" rule needs to auto-fix anything at all. Two tokens sharing a value stay a report.
- 413 automated checks across twelve suites; `tests/MANUAL-INTEGRATION.md` for
  what is LLM-driven and therefore not automatable.
