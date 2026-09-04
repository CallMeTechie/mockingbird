# Changelog

All notable changes to this project are documented in this file.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `--healthcheck` also names a project's `test` script, and `source_roots:` no
  longer hides the repo root from it. Root `files` commands are offered
  *alongside* the packages' own, not instead of them: which paths a linter really
  covers is its config's business, and Outpost's root config matches `server/`
  and `scripts/` only while the client's covers the client — keeping just one
  silently stops linting half the repo, which is what a first attempt at this
  did while still reporting PASS. A `whole` command at the root is kept for a
  kind no narrowed package offers. Found rebuilding Outpost's connect
  dialog: the change reached into `server/`, and a `source_roots: [client/src]`
  scan had never once offered the 1086 tests sitting behind the root `test`
  script. 472 checks.

### Changed

- `fix-policy.md`: a `files` healthcheck failure counts as yours only when it is
  absent from the baseline. The command measures the whole file, not the diff,
  so touching a file that already had violations reports them back at you —
  write the `HEAD` copy to a temp path, run the same command on it, and if the
  finding is there too it is pre-existing: report it, do not quietly repair it,
  and do not hang the verdict on it. Found on Outpost: a dead
  `refreshIdentities` in a file a marker had merely brushed.

## [0.1.10] - 2026-09-04

### Added

- The tokens stage sees functional colour notations: `rgb()`, `rgba()`, `hsl()`
  and `hsla()` count as raw values whenever they open with a digit, and the
  token map learns them from the definition files, so a finding can still name
  the one token that matches. Outpost defines its entire grey scale that way
  (`--gray: rgba(255,255,255,0.1)`), so a hex-only scan was blind to the
  most-copied values in the project — 42 findings that had never been reported,
  found by a reviewer who noticed the tool had said nothing where four raw
  values sat. `rgba(colors.$primary, .7)` does not open with a digit and stays
  unflagged: that is a token in use, however badly.

### Changed

- A `var(--x, raw)` fallback is only treated as "a token with a fallback" when
  `--x` is really defined somewhere — in a token definition file, as a CSS
  declaration in the scanned code, or through `setProperty()` from JS. When the
  property exists nowhere, the fallback is not a fallback: it is what the
  browser paints, every time, and hiding it was a silent pass. Outpost had six
  such lines behind `--error-color`, `--border-color` and `--hover-color`, none
  of which exists.

### Fixed

- `mb-design-check.sh` accepts `--root DIR` like every other command (0.1.4 gave
  it to the others and missed this one). It took the flag as the project path
  itself and died with `kein Manifest unter --root/docs/design/manifest.yaml`,
  which reads like a broken project rather than a mis-parsed call. An unknown
  option is now refused instead of being treated as a path. 468 checks.

## [0.1.9] - 2026-09-04

### Added

- Fifth adapter-contract function `mb_adapter_healthcheck` and the
  `--healthcheck` mode: the commands that prove the code still RUNS, named
  (`workdir<TAB>command<TAB>whole|files`) but never run by the script, so
  timeouts and permissions stay with the caller. Web reads the
  `lint`/`typecheck`/`build` scripts a project actually defines, never a
  long-runner like `dev`, and the manifest's `source_roots:` narrow a monorepo
  to the packages the screens live in. The third column matters on a real
  project: a repo-wide lint is red before mockingbird touches anything
  (Outpost: 80 pre-existing errors), so `lint` comes back as `files` and names
  the tool directly — the caller appends the paths this run changed — while a
  build stays `whole`. The verify chain runs them before any verdict; a failure is never a
  MATCH. All five stages read code as text and none of them notices a
  `ReferenceError` — on Outpost a control built from the guide called `t(...)`
  in a component that never took the `useTranslation` hook, and `structure`,
  `flow` and the seam check all passed it. mockingbird writes code itself, so
  "does it still run" belongs in the deterministic core. 455 checks.

### Changed

- `flow` and `semantic` stage mandates: a rule, a config or a condition cited
  as evidence — or as counter-evidence — has to be able to take effect at all.
  Check the parent selector, whether the class is really rendered, whether the
  required ancestor exists in the real DOM (`createPortal` does not move it),
  and look into the built artefact when there is one. Found twice on Outpost in
  one run: a reviewer refuted a working rule, and a `:has()` selector that
  looked present could never match across a portal boundary. A dead rule is the
  most dangerous evidence there is — it survives the seam check because its
  `file:line` exists.

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
