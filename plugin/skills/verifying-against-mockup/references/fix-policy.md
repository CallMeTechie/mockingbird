# Fix-Politik

Entscheidung: **alles automatisch fixen, was der Reviewer eindeutig mit
`file:line` belegen kann** — bewusst weiter gefasst als „nur
Präsentationsebene", weil die Beweislast (siehe `stages/semantic.md`) schon
vor dieser Politik greift: ein Fix wird nur vorgeschlagen, wenn die Kette
tatsächlich belegt ist. Umgesetzt wird die Entscheidung mit einem harten
Evidenz-Tor statt einer Pauschalerlaubnis.

## Automatisch gefixt, ohne Rückfrage

| Klasse | Bedingung | Re-Verifikation |
|---|---|---|
| `tokens` | genau **ein** exakt passendes Token für den Rohwert | `mockingbird-scope.sh --tokens` erneut: Treffer verschwunden |
| Label-Drift | reine Anzeigezeichenkette weicht vom Manifest-`label` ab; bei i18n geht der Fix in den **Katalogwert**, nie in den Key | grep auf den exakten String |
| Fehlendes statisches Element | `type` ∈ `{text, heading, divider, icon}`, **ohne** `data_source` und **ohne** `action` | `--locate` findet es danach, Tier A/B |
| `semantic` / `flow` | **nur** wenn Locator Tier A **oder** B **und** `terminal=<file:line>` existiert **und** der Reviewer die korrekte Alternativquelle **ebenfalls** mit `file:line` belegt hat | ein gezielter Re-Lauf der Stage auf genau diesem Element |

Bei mehrdeutigem Token (Wert liegt zwischen zwei Tokens): nicht fixbar, nur
melden.

## Nie automatisch

- **`semantic`/`flow` ohne vollständige Evidenz oder bei Tier C.** Nur
  Bericht mit konkretem Vorschlag.
- **Fehlende Zustands-Branches.** Einen `error`-Branch zu schreiben heißt
  zu entscheiden, was ein Fehler bedeutet und was Retry tut — das erzeugt
  plausibel aussehende leere Hüllen. Nur melden, mit Skizze.
- **`docs/design/manifest.yaml`.** Die Verify-Kette schreibt es nie —
  Design ändert man im Design-Dialog, mit dem User.
- **Alles außerhalb der Adapter-Globs.** Strukturell durchgesetzt, nicht
  nur hier gesagt: der Konsolidator holt die Allowlist per
  `mockingbird-scope.sh --fix-scope` und der `editor`-Agent verweigert
  jeden Edit außerhalb.

## Mechanik

1:1 preflight-Vorbild: Lock (`<project>/.claude/.mockingbird-running`) →
Snapshot **vor jedem Schreiben** (git-Commit
`mockingbird: snapshot <basename> before fix`, bei fremden gestagten
Änderungen `cp -- "<p>" "<p>.mockingbird.bak"`, bei Kollision
`.mockingbird<n>.bak`) → Fixes ausschließlich über `mockingbird:editor`,
der nur bereits entschiedene Edits bekommt, nie Urteilsspielraum → **Diff
gegen den Snapshot zeigen**, nicht nur eine Fix-Liste → Re-Verify mit
hartem Cap von einer Runde.

Für die drei rein deterministischen Klassen (Token, Label, statisches
Element) ist die Re-Verifikation LLM-frei — ein erneuter Lauf von
`--tokens`/`--locate`/grep genügt. Für `semantic`/`flow`-Fixes läuft genau
ein gezielter Reviewer-Dispatch auf den betroffenen Elementen, kein zweiter
voller Fan-out.
