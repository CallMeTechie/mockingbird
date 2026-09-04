# `docs/design/manifest.yaml` — normative schema

`schema: mockingbird/1`. This file is the source of truth for the UI design.
Everything else — the design block in a spec, the plan header, the per-task
design tables, the artboards — is a projection of it and gets regenerated from
it. Never hand-edit a rendered projection; edit the manifest and re-render.

Paths inside the manifest are always relative to the repository root.

## ID grammar

```
^UI-[A-Z0-9]+(-[A-Z0-9]+){0,3}$        max 40 characters
```

- Screen: `UI-<SCREEN>` — e.g. `UI-ORDERS`, `UI-ORDER-DETAIL`
- Element: `UI-<SCREEN>-<ELEM>` — e.g. `UI-ORDERS-TABLE`
- Sub-element / disambiguation: `UI-<SCREEN>-<ELEM>-<SUB>` or `-01`, `-02`

`UI-SHELL` is reserved for chrome shared across every screen (navigation,
toasts, a global error banner). Elements shared across screens live there.

**IDs are never renamed.** A rename is a new ID plus an entry under `retired:`
with `superseded_by:` — a plan or task brief written against the old ID must
resolve to an explanation, not to nothing.

## Top-level keys

| Key | Required | Meaning |
| - | - | - |
| `schema` | yes | Literal `mockingbird/1` |
| `project` | yes | Short project slug, free text |
| `revision` | yes | Monotonically increasing integer, raised on every approved run |
| `updated` | yes | ISO date of the last approved run |
| `design_system` | yes | Path to `design-system.md` |
| `mockups_index` | yes | Path to the artboard contact sheet |
| `tokens_css` | yes | Path to the shared token stylesheet |
| `adapters` | yes | Map of adapter name to `{locator, attribute?, visual_check}` |
| `primary_adapter` | yes | Key into `adapters`; the adapter `/design-verify` uses by default |
| `changelog` | yes | List of `{rev, date, summary, touched: [element/screen ids]}` |
| `screens` | yes | List of screen objects, see below |
| `flows` | no | List of `{id, title, steps: [screen ids]}` |
| `allocations` | no | Written by `/design-split`; see `splitting.md` |
| `retired` | no | List of `{id, rev, superseded_by, reason}` |

## `screens[]`

| Key | Required | Meaning |
| - | - | - |
| `id` | yes | `UI-<SCREEN>` |
| `kind` | yes | `page \| dialog \| panel \| view \| flow-step \| shared` |
| `title` | yes | Human-readable screen name |
| `artboard` | yes* | Path to the HTML artboard, or `null` before one is drawn |
| `route_hint` | no | Free text, e.g. `/orders` |
| `description` | no | One or two sentences |
| `uses` | no | IDs of shared elements (usually from `UI-SHELL`) this screen uses but does not own |
| `presentation` | required for dialog/panel/overlay-like screens | One-line flow map `{ over: <screen id>, trigger: "…", size: "…", dismiss: "…", keyboard: "…" }` — how the screen appears; rendered as the artboard's context header and in the contact sheet |
| `guide` | recommended | Path to the implementation guide, by convention `docs/design/guides/<screen-slug>.md` |
| `elements` | yes | List of element objects, see below |

\* A screen may exist in the manifest with `artboard: null` while it is still
being drawn. It must not be referenced by a *file path* anywhere outside the
manifest until the artboard exists — only by its ID, which the preflight
factchecker does not try to resolve as a path.

## `elements[]`

| Key | Required | Meaning |
| - | - | - |
| `id` | yes | `UI-<SCREEN>-<ELEM>` |
| `type` | yes | Closed vocabulary, see `element-vocabulary.md` |
| `label` | yes | The visible label, verbatim — this is what gets built |
| `status` | yes | `required \| recommended \| deferred` (+ dated `deferred_reason` if deferred) |
| `verify` | yes | `required \| recommended \| skip` (+ `reason` if skip). Drives `/design-verify`, independent from `status` (which drives whether it should be *built* at all) |
| `data_source` | yes | `static` for elements with no data, or a description/endpoint for data-bearing ones |
| `semantic_anchor` | required if `data_source != static` | See below — the field the plausibility check runs against |
| `columns` | only for `type: table \| list` | List of `{key, label, anchor}` |
| `states` | yes | List of `{id, copy?, ref?}`; `default` is mandatory |
| `locators` | recommended | Map of adapter name to a locator hint, e.g. `web: "[data-ui-id='UI-ORDERS-TABLE']"` |
| `style_ref` | no | Anchor into `design-system.md` |

## `semantic_anchor` — the load-bearing field

This is what makes "a dropdown labelled Abteilung must show departments, not
groups" a checkable statement instead of a taste judgement.

| Key | Required | Meaning |
| - | - | - |
| `means` | yes | One sentence, in business terms, never about layout |
| `concept` | recommended | The single business concept this element represents |
| `aliases` | recommended | List of legitimate technical spellings (`dept`, `orgUnit`) |
| `not` | strongly recommended | The confusable neighbours (`team`, `group`, `cost_center`) — the single most valuable field: the common failure is not "looks wrong", it's "looks plausible, wrong business quantity" |
| `cardinality` | if applicable | `one \| many` |
| `unit` | if data-bearing | `count \| currency \| date \| duration \| percent \| text \| enum \| bytes` |
| `example` | if data-bearing | A realistic value — this exact value belongs in the artboard, never lorem ipsum |
| `source_of_truth` | optional | Field/endpoint the value ultimately comes from |
| `empty_means` | for lists/metrics | What an empty result means in business terms — feeds the empty-state copy |

## `states[]`

`id: default` is mandatory on every element. Recommended canonical states:
`loading`, `empty`, `partial`, `error`, `disabled`, `selected`, `success`.
A state may carry `copy:` (the exact text to render) or `ref:` (pointing at
another element, e.g. an element's `empty` state referencing a dedicated
empty-state element).

## Versioning — two independent signals, deliberately

- `revision` + `changelog[].touched` is the *semantic* signal: it lets a
  sub-spec decide whether *its* screens are affected without hashing anything.
- The manifest file's own sha256 is the *tamper* signal. It is never stored
  inside the manifest (self-reference); it lives in the design block's facts
  comment and in the hook's state file. A hash that moved without `revision`
  increasing means something edited the manifest outside the normal flow.

`touched` is maintained by the model and can be incomplete — it only suppresses
unnecessary re-renders, it is never the sole staleness signal. The file hash
catches every change, recorded or not.

## Schreibform — was der Parser versteht (verbindlich)

mockingbird liest das Manifest ohne `yq` mit einem **strikten Subset-Parser**
(`plugin/lib/mockingbird-manifest.awk`), der bei allem außerhalb des Subsets
mit Exit 5 **verweigert statt zu raten**. Ein halb gelesenes Manifest würde
jede Prüfung danach vergiften. Halte dich deshalb exakt an diese Form:

- **Einrückung: 2 Leerzeichen**, nie Tabs. Screen-Items `  - id:`,
  Screen-Felder mit 4, Element-Items `      - id:`, Element-Felder mit 8,
  Kinder von `semantic_anchor:`/`locators:` mit 10 Leerzeichen.
- **`states:` und `columns:` als einzeilige Flow-Maps:**
  `- { id: loading, copy: "Skeleton-Zeilen, keine Spinner." }` — **nicht**
  im Block-Stil über mehrere Zeilen.
- **Listen inline:** `aliases: [dept, orgUnit]`, `not: [team, group]`,
  `uses: [UI-SHELL-NAV]`, `owns: [UI-ORDERS]`.
- **Keine mehrzeiligen Skalare** (`|`, `>`), **keine Anker/Aliase** (`&`,
  `*`), **keine gequoteten Schlüssel**. Kommas in Werten sind erlaubt, wenn
  der Wert in `"…"` steht.
- `semantic_anchor:` ist eine verschachtelte Map (Kinder je eine Zeile),
  `locators:` ebenso (`web: "[data-ui-id='…']"`).
- Unbekannte, aber wohlgeformte Skalar-Schlüssel werden ignoriert (vorwärts-
  kompatibel); ein Verstoß gegen die **Struktur** ist ein Fehler.

Nach jedem Schreiben des Manifests:
`${CLAUDE_PLUGIN_ROOT}/scripts/mockingbird-scope.sh --validate --root <projekt>` —
Exit 5 heißt „außerhalb des Subsets", Exit 4 „gültig geparst, aber Regel
verletzt" (die Meldung nennt welche), 0 heißt fertig.
