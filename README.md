# mockingbird

Frontend design that survives the project.

Agentic development is good at building what a plan says and bad at remembering what a design
meant. Either no design is made at all — and it shows — or one is made, and it evaporates: the
spec is prose, the plan has no design field, and the subagent that actually writes the component
never sees either. Three tasks later you are prompting about paddings again.

mockingbird works the design out with you, writes it down in a form a machine can check, and
carries it all the way to the implementer — then checks the built result against it.

## Why

- **The design becomes an artefact, not a conversation.** HTML artboards you can open in a
  browser, plus a machine-readable `manifest.yaml` that names every screen, element, state and
  data source.
- **It survives decomposition.** One manifest per project; every spec, plan and *task brief*
  carries the slice it needs plus the path back to the whole. Split a spec in three and all
  three still know the design.
- **It plugs into preflight without touching it.** The design block in the spec is built like
  preflight's own security block, so preflight's plan review checks design requirements against
  plan steps for free.
- **It checks meaning, not just looks.** The point is not "does it match the picture". The point
  is whether a dropdown labelled `Abteilung` is actually wired to departments — and not to
  groups, teams or cost centres.
- **It refuses to guess.** Every blocking finding must show the last link of the chain with
  `file:line`. No evidence means `unverified`, never `violated`. That rule is enforced in bash,
  not asked for in a prompt.

## Pipeline

```
  /design            dialogue -> design-system.md + tokens.css + artboards + manifest.yaml
     |
  /design-spec       renders the design block into the spec  (preflight reads it as requirements)
     |
  /design-sync       plan header + global constraints + per-task design tables
  /design-split      allocates screens across sub-specs, one owner each
     |
  ... implementation ...
     |
  /design-verify     gate -> 5 parallel reviewers -> deterministic coverage -> fixes -> diff
                     structure | semantic | states | tokens | flow
```

## Install

```
/plugin marketplace add CallMeTechie/mockingbird
/plugin install mockingbird@mockingbird
```

Local checkout instead:

```
claude plugin install /path/to/mockingbird/plugin
```

## Commands

| Command | What it does |
| - | - |
| `/design` | Works the design out with you and writes `docs/design/`. `--extend` to add to an existing manifest. |
| `/design-spec` | Renders the design block into a superpowers spec. |
| `/design-sync` | Refreshes the block, the plan header, the global constraints and the per-task tables. |
| `/design-split` | Records which sub-spec owns which screens when a spec is decomposed. |
| `/design-check` | Read-only: checks the manifest and every derived document against the invariants. |
| `/design-verify` | *Not built yet.* Will check the built result against the manifest, apply provable fixes, report a verdict. |
| `/mockingbird-bench` | *Not built yet.* Will measure recall, false positives and hallucination rate against fixtures. |

## Status

Built and tested: the plugin scaffold, the hook layer (path detection, two-hash
drift state, session-aware locking), the design marker block (placement next
to preflight's security block, idempotent rendering), the manifest parser and
validator, and — the load-bearing piece — propagation into a plan and a
per-task design table, proven against the real, vendored superpowers
task-brief cut rather than a paraphrase of it.

Not built yet: the `designing-frontends` dialogue skill and its `/design`
command, the semantic verification chain (`/design-verify`, the
structure/semantic/states/tokens/flow reviewers, the plausibility check that
gives this plugin its name — "a dropdown labelled *Abteilung* must actually
show departments"), and its bench.

## Artefacts it writes into your project

```
docs/design/
  manifest.yaml        source of truth, machine-readable
  design-system.md     colour roles, type scale, spacing, components, do-not list
  mockups/
    index.html         contact sheet: every artboard side by side
    tokens.css         one token file, linked by every artboard
    <screen>.html      one artboard per screen, every state stacked and labelled
```

State lives under `<project>/.claude/` and never under the plugin directory.
`touch <project>/.claude/.mockingbird-off` disables the nudges for a project.

## Tests

Plain bash, no framework.

```
tests/run-all.sh                    # everything (206 checks as of this writing)
tests/run-hook-tests.sh             # path detection, state, locking, end-to-end hook
tests/run-block-tests.sh            # marker block: exit contract, fences, idempotent render
tests/run-manifest-tests.sh         # strict-subset YAML parser, TSV normal form, validation
tests/run-render-tests.sh           # rendering the block, inserting it, propagating failures
tests/run-plan-propagation-tests.sh # the design table survives the REAL superpowers task-brief cut
```

`tests/run-scope-tests.sh` and `tests/run-bench-tests.sh` (the verify chain
and its quality bench) are not built yet — see the roadmap below.

`tests/MANUAL-INTEGRATION.md` covers what is LLM-driven and therefore not automatable.

## License

MIT
