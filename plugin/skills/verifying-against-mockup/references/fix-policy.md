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
- **Alles außerhalb der Allowlist.** Strukturell durchgesetzt, nicht nur
  hier gesagt: der Konsolidator holt sie per
  `mockingbird-scope.sh --fix-scope`, der `editor`-Agent verweigert jeden
  Edit außerhalb. Die Allowlist ist die Vereinigung aus Komponenten-Globs
  (Element-Fixes) und Stylesheet-Globs (Token-Fixes); Zeilen mit `!` sind
  Ausschlüsse — die Token-**Definitionsdateien** (`tokens_css`,
  `token_definitions`) sind nie editierbar, sie sind die Quelle.

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

## Lauffähigkeit — vor jedem Verdikt, nach jedem Schreiben

```
mockingbird-scope.sh --healthcheck --root <projekt>
```

Gibt `<arbeitsverzeichnis><TAB><befehl><TAB>whole|files` je Zeile aus
(Exit 3, wenn das Projekt keinen solchen Befehl anbietet — das ist kein
Freispruch, sondern „nicht prüfbar"). Die dritte Spalte entscheidet, wie
ausgeführt wird:

- **`files`** — die soeben geänderten Pfade anhängen. Ein projektweiter Lint
  auf einem Bestandsprojekt ist rot, bevor mockingbird irgendetwas anfasst
  (Outpost: 80 vorhandene Fehler); als Tor sagt er dann nichts aus. Gemessen
  wird, was dieser Lauf geschrieben hat.
- **`whole`** — unverändert ausführen; der Befehl ist nur ganzheitlich
  sinnvoll (Build, Typecheck).

Schlägt einer fehl, ist das Ergebnis **kein MATCH**, egal was die fünf
Stufen sagen: der Code läuft nicht.

Der Grund steht im Kopf von `plugin/scripts/adapters/web.sh`: alle fünf
Stufen lesen Code als Text, keine bemerkt einen `ReferenceError`. Auf
Outpost (2026-09-04) rief ein nach Anleitung gebauter Umschalter `t(...)`
in einer Komponente, die den `useTranslation`-Hook nie geholt hatte — die
Seite wäre beim Rendern abgestürzt, und `structure`, `flow` **und** der
Seam-Check haben ihn durchgewinkt. mockingbird schreibt selbst Code; wer
Code schreibt, prüft, dass er läuft.
