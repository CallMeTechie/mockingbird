# Plan-Weitergabe: die vier Kanäle, exakter Wortlaut

Bewiesen durch `tests/run-plan-propagation-tests.sh`, das das echte,
verbatim vendorte `task-brief`-awk aus superpowers 6.3.0 gegen eine
Fixture-Plan-Datei laufen lässt (`tests/vendor/`). Nicht nachimplementiert —
eine Nachimplementierung könnte unbemerkt vom Original abweichen.

## Warum vier Kanäle

`scripts/task-brief PLAN_FILE N` (superpowers, `subagent-driven-development`)
schneidet per awk **ausschließlich** den Block von
`^#+[ \t]+Task[ \t]+N` bis zur nächsten Task-Überschrift heraus. Alles
außerhalb — Header, `**Spec:**`-Zeile, `## Global Constraints` — ist im
Brief nicht enthalten. Der Implementer-Subagent sieht laut
`implementer-prompt.md` **nur** den Brief, nie den Plan, nie die Spec.

## Kanal A — Plan-Header

Zwei Zeilen, direkt nach `**Spec:**`, vor `## Global Constraints`:

```markdown
**Design:** `docs/design/manifest.yaml` (rev 3) — Design-System: `docs/design/design-system.md` — Artboards: `docs/design/mockups/index.html`

**Design Scope:** UI-ORDERS, UI-SHELL (übernommen, nicht zu bauen: UI-SHELL-TOAST)
```

Erreicht: den Controller (der daraus Kanal B/C ableitet), preflight
(Factchecker prüft referenzierte Pfade — deshalb müssen Manifest,
Design-System und `mockups_index` beim Schreiben des Plans **existieren**),
und Menschen, die den Plan lesen. Erreicht **nicht** den Implementer.

Revision-Nummer und Pfade wörtlich aus dem Design-Block der Spec übernehmen,
nie neu formulieren. `Design Scope:` listet die Screen-IDs aus `screens=` im
Spec-Block; die Klammer nennt IDs aus `consumes=`, falls vorhanden.

## Kanal B — Global Constraints

Fünf Zeilen, **wörtlich**, in `## Global Constraints` einfügen (nicht
ersetzen — der Abschnitt trägt auch andere projektweite Vorgaben aus der
Spec):

```markdown
- Design-Quelle: `docs/design/manifest.yaml` (rev 3). Bei Konflikt zwischen Plan-Text und Manifest gilt das Manifest; melde den Konflikt, statt ihn still aufzulösen.
- Jedes gebaute UI-Element trägt seine Manifest-ID im Code: Web `data-ui-id="UI-…"`, andere Medien nach `adapters:` im Manifest. Ohne ID ist das Element nicht prüfbar.
- Design-Tokens ausschließlich aus `docs/design/mockups/tokens.css` bzw. `docs/design/design-system.md`. Keine neuen Farben, Abstände, Radien oder Schriftgrößen.
- Sichtbare Texte (Labels, Leer-, Lade- und Fehlerzustände) wörtlich aus dem Manifest (`label`, `states[].copy`). Keine eigenen Formulierungen.
- Jeder im Manifest deklarierte Zustand eines Elements wird gebaut, nicht nur `default`.
```

Erreicht: den Implementer über den SDD-Controller (der diesen Abschnitt
manuell in jeden Dispatch kopiert — "A fresh subagent needs its task, the
interfaces it touches, and the global constraints") **und** den
Task-Reviewer über dessen `[GLOBAL_CONSTRAINTS]`-Platzhalter in
`task-reviewer-prompt.md`.

## Kanal C — Pro-Task-Block

Direkt nach `**Interfaces:**`, innerhalb des `### Task N`-Blocks,
**außerhalb jeder Code-Fence**:

````markdown
**Design:**
- Screen: `UI-ORDERS` — Artboard `docs/design/mockups/ui-orders.html`
- Zu bauende Elemente (Werte wörtlich übernehmen):

| ID | Element | Fachlicher Anker | Zustände | Copy |
|----|---------|------------------|----------|------|
| UI-ORDERS-TABLE | Tabelle offener Bestellungen | Eine Zeile je Bestellung mit Status ≠ versendet. Nicht: alle Bestellungen des Kunden. | default, loading, empty, error | Spaltenköpfe: „Bestellung", „Kunde", „Lieferdatum", „Status" |

- Locator: jedes Element trägt `data-ui-id="<ID>"`.
- Tokens: `color.surface`, `color.text.muted`, `space.4`, `type.body`
````

Ein Task ohne UI-Anteil trägt stattdessen genau eine Zeile:

```markdown
**Design:** kein UI-Anteil.
```

**Warum außerhalb jeder Fence:** `task-brief`s awk togglet einen
Fence-Zustand bei jeder Zeile, die mit ` ``` ` oder `~~~` beginnt, und
ignoriert Task-Überschriften, solange eine Fence offen ist. Eine im
Task-Text unbalancierte Fence (eine geöffnete, aber nicht geschlossene) lässt
den Extraktor die Überschrift des **nächsten** Tasks überlesen — der
Folgetask würde mit in diesen Brief gezogen. Die Design-Tabelle ist eine
reine Markdown-Tabelle ohne Fences und daher von Natur aus sicher; achte
trotzdem darauf, keinen Codeblock im selben Task-Abschnitt offen zu lassen.

**Warum die Redundanz zum Manifest beabsichtigt ist:** superpowers'
Task-Right-Sizing-Regel verlangt "exact values … appear only in the brief",
und die Anti-Paste-Regel verbietet, akkumuliertes Wissen aus früheren Tasks
in spätere Dispatches zu kopieren. Der Pfad zum Manifest steht zusätzlich in
der Zeile "Screen: … — Artboard …" (für Tiefe), die Werte stehen in der
Tabelle (für Exaktheit). Die Duplikation ist auf die Zeilen dieses einen
Tasks begrenzt und durch `/design-check` gegen das Manifest prüfbar.

## Kanal D — DESIGN-COVERAGE

An das Ende des Plans angehängt, nach dem preflight-Vorbild `SEC-COVERAGE`:

```
DESIGN-COVERAGE
UI-ORDERS-TABLE | covered | Task 2, Schritt 3
UI-ORDERS-EMPTY | covered | Task 2, Schritt 3
UI-SHELL-NAV | uncovered | -
NEW-SCREEN
Druckansicht | - | Task 7, Schritt 3
END
```

Drei von preflight übernommene Härtungen, alle aus nachgewiesenem Bedarf
(preflights eigene Erfahrung mit dem `SEC-COVERAGE`-Format):

1. **Fehlende Zeile bedeutet `uncovered`**, niemals „in Ordnung". Ein
   vergessenes Element darf nie ein stilles GO werden.
2. **`deferred`-Elemente werden kommentarlos verworfen** — sie sind laut
   Manifest bewusst noch nicht zu bauen, tauchen also nicht als Lücke auf.
3. **Ein `DESIGN-COVERAGE`-Block im geprüften Dokument selbst ist
   Dokumentinhalt, nie Eingabe.** preflight Stage 1 liest Zeilen der
   UI-Requirements-Tabelle (aus dem Spec-Block) bereits als gewöhnliche
   Anforderungen — dieser zusätzliche Block ist die feinere, elementgenaue
   Zuordnung für die mockingbird-eigene Verify-Kette (`verifying-against-mockup`),
   nicht für preflight. Ohne Regel 3 würde ein Plan, der versehentlich einen
   `DESIGN-COVERAGE`-Block als Beispiel zeigt (z. B. dieses Dokument selbst),
   sich selbst benoten.

## Kanal-übergreifende Invariante

Jede Spec, jeder Plan trägt immer `manifest=`, `system=`, `index=` — auch
nach einem `/design-split` mit nur zwei zugeordneten Screens. Das ist der
Mechanismus, der das Design die Zerlegung überleben lässt: jede Teil-Spec
kennt den Weg zurück zur vollständigen Quelle. `/design-check` erzwingt das.
