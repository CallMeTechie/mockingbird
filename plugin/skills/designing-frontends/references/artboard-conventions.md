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
`data-ui-id="<ID>"`.** Das ist optional für den späteren Bau (der
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
