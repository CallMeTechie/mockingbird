# Der Design-Block in einer Spec

Format, Platzierung und Schutzmechanik sind in
`plugin/lib/mockingbird-blocklib.sh` implementiert und durch
`tests/run-block-tests.sh` (39 Fälle) sowie `tests/run-render-tests.sh`
(Rendering + Platzierung) abgesichert. Dieses Dokument beschreibt nur, WAS
und WARUM — für das WIE die Bibliothek selbst lesen.

## Aufbau

```markdown
<!-- mockingbird:design:begin -->
<!-- design: manifest=docs/design/manifest.yaml design_rev=3
     design_hash=sha256:… system=docs/design/design-system.md
     index=docs/design/mockups/index.html adapter=web
     screens=UI-ORDERS,UI-SHELL consumes=UI-SHELL-NAV -->
<!-- Generiert aus docs/design/manifest.yaml. Nicht von Hand ändern —
     Änderungen hier werden beim nächsten mockingbird-Lauf überschrieben.
     Design ändern heißt Manifest ändern. -->

## UI Requirements

| ID | Element | Screen | Status | Fachlicher Anker |
|----|---------|--------|--------|------------------|
| UI-ORDERS-TABLE | Tabelle offener Bestellungen | UI-ORDERS | required | … |

**Übernommene Elemente** (hier nicht zu bauen, nur zu verwenden):
- `UI-SHELL-NAV` — Hauptnavigation

Artboards: `docs/design/mockups/index.html` · Design-System: `docs/design/design-system.md`
<!-- mockingbird:design:end -->
```

Neun definierte Keys im Fakten-Kommentar: `manifest`, `design_rev`,
`design_hash`, `system`, `index`, `adapter`, `screens` (Pflicht),
`consumes`, `shared` (optional). Kein `key=value`-Paar über Zeilen
gebrochen, Listenwerte kommagetrennt ohne Leerzeichen — geprüft von
`mb_design_facts_valid`.

## Warum die Tabelle preflight erreicht, ohne dass preflight etwas weiß

preflight Stage 1 der Plan-Review-Kette fragt: „Are all spec requirements
covered by a plan step?" — und liest dafür jede Tabellenzeile der Spec als
gewöhnliche Anforderung, genau wie beim eigenen `SEC-COVERAGE`-Security-Block.
Die UI-Requirements-Tabelle ist bewusst in derselben Bauart gehalten, damit
dieser Mechanismus ohne eine Zeile preflight-Code greift.

## Platzierung relativ zum Security-Block

Immer **oberhalb** von `<!-- preflight:security:begin -->`, nie darin.
`mb_insert_block` sucht die erste fence-gefilterte Vorkommen der
Security-Begin-Zeile und fügt davor ein; ohne Security-Block wird an EOF
angehängt. Keine Code-Abhängigkeit zu preflight — die Zeichenkette ist eine
reine Textkonvention.

## Warum es eine Projektion ist, keine zweite Wahrheit

Der Block wird bei jedem Sync komplett neu gerendert und ersetzt, nie
manuell nachbearbeitet. Der Render-Schritt ist idempotent: erzeugt er
byteidentischen Text, schreibt `mb_insert_block` nichts (Exit 4) — das bricht
die Nudge-Schleife mit preflight (siehe `carrying-design-through/SKILL.md`,
Abschnitt „Advisory, nie blockierend", und `plugin/hooks/detect-design-context.sh`).

**Bekanntes Restrisiko:** `preflight:editor` trägt Schreibrechte und darf
laut preflights eigenem Ablauf alles außerhalb des Security-Blocks anfassen
— auch unseren Block. Strukturell nicht verhinderbar, ohne preflight zu
ändern (bewusst ausgeschlossen). Entschärft durch die Projektions-
Eigenschaft: eine Fremdänderung ist verlustfrei rückgängig, weil das
Original im Manifest steht — der nächste Sync rendert den Block einfach neu.
