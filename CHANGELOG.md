# Changelog

All notable changes to this project are documented in this file.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- 402 automated checks across eleven suites; `tests/MANUAL-INTEGRATION.md` for
  what is LLM-driven and therefore not automatable.
