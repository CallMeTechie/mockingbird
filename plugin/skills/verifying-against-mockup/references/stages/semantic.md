# Stage: `semantic` — Label ↔ Binding ↔ Datenquelle ↔ Fachdaten

**Dein Mandat ist ausschließlich diese Stage.** Prüfe keine andere Kategorie.

## Die Frage

Zeigt ein Element wirklich das, was sein Label verspricht — fachlich, nicht
nur visuell? Ein Dropdown „Abteilung" muss Abteilungen laden, nicht Gruppen,
Kostenstellen oder Teams. Das ist der Daseinsgrund dieses ganzen Plugins.

## Die Naht — fünf Glieder, jedes mit Beleg

Verfolge für jedes zugewiesene Element die Kette vom sichtbaren Label bis
zum tatsächlichen Datenursprung:

| Glied | Beispiel Web | Was du suchst |
|---|---|---|
| `render` | Die Komponente, die das Label rendert | `file:line` |
| `binding` | Prop/State, die die Optionen füttert | `file:line` |
| `source` | Hook/Query/Fetch, die das Binding erzeugt | `file:line` |
| `handler` | Route-Handler / Resolver / Service-Methode | `file:line` |
| `terminal` | Tabelle, Typ, Enum, Seed, Literal-Array | `file:line` + gefundener Begriff |

Plattform-Hinweise (wo Binding/Datenquelle typischerweise aussehen), nie
Regeln: `references/adapters/<adapter>.md`.

## Ausgabeformat, verbindlich

```
MB-SEAM
<element-id> | tier=A|B|C | render=<f:l|-> | binding=<f:l|-> | source=<f:l|-> | handler=<f:l|-> | terminal=<f:l|-> | found=<concept> | ok|partial|violated|unverified:<reason>
END
```

`tier` = die Verlässlichkeit deines Locators für **dieses** Element:
`A` = expliziter `data-ui-id`-Marker gefunden, `B` = eindeutiger
Label-String-Treffer, `C` = Namenskonvention/Fuzzy-Match. Nutze
`${CLAUDE_PLUGIN_ROOT}/scripts/mockingbird-scope.sh --locate <element-id> --root <projekt>`,
um Kandidaten mit Tier zu bekommen — rate den Tier nicht selbst.

Zusätzlich, falls relevant, ein `MB-COVERAGE`-Eintrag pro Element (Format:
`references/../coverage-rules.md`), Stage-Key `semantic`.

## Vier Urteilsklassen

- **`ok`** — Kette vollständig, `found` passt zu `concept`/`aliases` im
  semantischen Anker, **oder** die Kette enthält eine nachgewiesene
  Verengung (`WHERE type='department'`, `.filter(u => u.kind ===
  'DEPARTMENT')`, eine Mapper-Funktion). Diese Verengung ist der Beweis,
  dass eine Umbenennung legitim ist — `orgUnits`, auf Abteilungen gefiltert,
  ist korrekt und darf nicht als Abweichung gelten.
- **`partial`** — Kette vollständig, Begriff passt grundsätzlich, aber die
  **Verengung fehlt**: die Quelle liefert die Obermenge (alle Org-Einheiten
  statt Abteilungen), obwohl das Label die engere Menge verspricht. Das ist
  die subtile Variante des Fehlers — meist schwerer zu finden als eine
  komplett falsche Quelle.
- **`violated`** — `found` trifft einen `not:`-Nachbarn aus dem
  semantischen Anker oder einen erkennbar fremden Fachbegriff, ohne
  Mapping-Beleg. Braucht zwingend ein belegtes `terminal=<file:line>` —
  ohne das wird dein Befund automatisch auf `unverified:no-locator`
  herabgestuft (`mockingbird-scope.sh --check-seam` erzwingt das).
- **`unverified:<reason>`**, geschlossenes Vokabular:
  - `no-locator` — Element nicht auffindbar
  - `external-boundary` — Kette verlässt das Repo (Service/DB nicht im Repo)
  - `dynamic` — Dispatch dynamisch/konfigurationsgetrieben, nicht statisch verfolgbar
  - `out-of-scope` — der Adapter kann diese Prüfung nicht (`capabilities.semantic=no`)

## Zusätzliche, billige und verlässliche Klasse: `stub-data`

Das Endglied ist ein Literal-Array (`['Gruppe A', 'Gruppe B']`) oder eine
offensichtliche Test-Fixture statt einer echten Datenquelle. Immer
`violated`, weil das Endglied per Definition mit `file:line` belegt ist —
das ist der häufigste echte Treffer in der Praxis.

## Wann du schweigen musst

Du prüfst Code gegen Manifest. Du weißt nicht, welche Seite recht hat. Ein
`violated` benennt immer beide Seiten und stellt die Frage, welche falsch
ist — es entscheidet nicht. **Ändere niemals das Manifest, und schlage
niemals eine Manifest-Änderung als Fix vor.** Findest du keine Kette,
melde `unverified:no-locator` mit dem letzten Glied, das du belegen
konntest — nie `violated`, nur weil du nichts gefunden hast. „Ich konnte
nicht mal zeigen, wo ich aufgehört habe zu suchen" ist von „nicht
implementiert" nicht unterscheidbar und wird entsprechend behandelt.
