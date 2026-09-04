# Artboard-Konventionen (Phase 4, `artboard-writer`)

## Format

Statisches HTML, kein Build-Schritt, kein CDN, kein Framework. Tokens per
`<link rel="stylesheet" href="./tokens.css">` — funktioniert über `file://`
ohne Server. Jedes Artboard ist entweder ein Volldokument
(`<!doctype html>…`) oder ein Fragment, das `docs/design/mockups/index.html`
einbettet (Kontaktbogen: alle Screens nebeneinander, mit Überschrift je
Screen).

## Locator-Attribute — der wichtigste Punkt

**Jedes Element, das im Manifest eine ID hat, trägt im Artboard
`data-ui-id="<ID>"`.** (Im Produktivcode zählt zusätzlich die
React-Prop-Schreibweise `dataUiId="<ID>"` — nötig, wenn eine gemeinsame
Komponente das Element rendert und den Marker durchreichen muss.) Das ist optional für den späteren Bau (der
`/design-verify`-Locator degradiert sauber auf schwächere Erkennung ohne
Marker), aber verbindlich für das Artboard selbst — es ist die einzige
Stelle, an der die Zuordnung Manifest-Element ↔ visuelles Element eindeutig
und maschinenlesbar wird.

## Zustände — alle, nicht nur `default`

**Jeder im Manifest deklarierte Zustand eines Elements wird gerendert**, als
eigener, beschrifteter Abschnitt mit `data-ui-state="<state-id>"`:

```html
<section data-ui-state="default">…</section>
<section data-ui-state="loading">…</section>
<section data-ui-state="empty">…</section>
<section data-ui-state="error">…</section>
```

Kein JavaScript nötig — alle Zustände sind gleichzeitig sichtbar,
übereinander gestapelt mit einer kleinen Beschriftung je Abschnitt. Das ist
bewusst redundanter als ein interaktiver Prototyp, aber macht jeden Zustand
auf einen Blick vergleichbar, ohne Klicks zu simulieren.

## Inhalte — realistisch, nie Lorem Ipsum

Werte aus `semantic_anchor.example` im Manifest übernehmen. Ein Dropdown
„Abteilung" zeigt im Artboard echte Abteilungsnamen aus dem Projektkontext
(oder plausible Platzhalter wie „Vertrieb", „Logistik", „Einkauf") — nie
„Option 1, Option 2, Option 3". Das ist keine Kosmetik: unrealistische
Platzhalter im Artboard verschleiern später genau die Verwechslung, die
`/design-verify` aufdecken soll.

## Was ein Artboard nicht ist

Kein interaktiver Prototyp, keine echte Datenanbindung, kein Klickpfad.
Navigation zwischen Screens läuft über einfache `<a href="./andere-seite.html">`-
Links im Kontaktbogen, mehr nicht.

## Darstellungskontext — jedes Artboard erklärt, WIE es erscheint

Ein Dialog-Artboard, das nur den Dialog zeigt, sagt nicht, dass es ein
Dialog ist (Rückmeldung aus dem ersten Live-Dialog, 2026-09-03). Deshalb
beginnt **jedes** Artboard direkt nach `<body>` mit einem sichtbaren
Kontextblock `<header class="mb-context">`, der aus dem Manifest kommt:

- **Art** (`kind`): Seite · Dialog (modal, mit Backdrop) · Panel · Ansicht · Flow-Schritt · Shell
- **Erscheint über / in**: welcher Screen darunter liegt (`presentation.over`)
- **Auslöser**: was ihn öffnet (`presentation.trigger` — Aktion, Taste, Kontextmenü)
- **Größe und Position**: `presentation.size` (z. B. „mittig, 40 rem breit, max. 80 vh")
- **Schließen**: `presentation.dismiss` (Esc, Klick auf Backdrop, Abbrechen, nach Erfolg automatisch)
- **Tastatur**: die Haupttasten dieses Screens

Für `kind: page` genügt: Art, Route (`route_hint`), Tastatur. Im Manifest
steht das als einzeilige Flow-Map am Screen:
`presentation: { over: UI-SERVERS, trigger: "Kontextmenü › Bearbeiten / Taste E", size: "mittig, 44rem, max 85vh", dismiss: "Esc, Backdrop, Abbrechen" }`

## Flaches CSS, damit der Kontaktbogen Auszüge einbetten kann

`index.html` zeigt jedes Artboard **als eingebetteten Auszug mit Erklärung**,
nicht als `<iframe>` (Frames über `file://` sind in vielen Browsern leer,
und ein kommentarloser Frame-Katalog erklärt nichts). Dafür kopiert der
Generator (`scripts/mb-render-index.sh`) Markup und Styles jedes Artboards in
die Indexseite und stellt jedem Selektor `#ab-<slug>` voran. Das funktioniert
nur, wenn Artboard-CSS flach bleibt: **ein `<style>`-Block**, keine
`@import`, kein Nesting; `@media`/`@keyframes` sind erlaubt. Alle
Regeln, die das Artboard-Layout betreffen, hängen an Klassen, nicht an
`body`/`html` (die gelten in der Indexseite nicht mehr). Der gesamte
Artboard-Inhalt steht in **einem** `<main class="mb-artboard">`.
