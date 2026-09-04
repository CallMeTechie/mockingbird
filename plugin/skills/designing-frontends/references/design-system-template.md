# `docs/design/design-system.md` — Vorlage

Kein starres Format, aber diese Abschnitte gehören in jedes Design-System,
weil `/design-verify`s `tokens`-Stufe (sobald gebaut) und die Artboards
selbst sich darauf verlassen:

## Farben

Rollen, nicht nur Werte — `surface`, `text`, `text-muted`, `border`,
`accent`, `success`, `warning`, `error`, jeweils mit Hex/HSL-Wert und einer
Zeile, wann sie verwendet wird. Dieselben Rollen als CSS-Custom-Properties
in `docs/design/mockups/tokens.css` spiegeln.

## Typografie

Eine kleine Skala (typischerweise 4–6 Stufen), mit Zuordnung zu Zweck
(„Seitentitel", „Kartenüberschrift", „Fließtext", „Meta/Caption").

## Abstände

Eine Skala (z. B. `4px`-Basis: `space.1`=4px, `space.2`=8px, `space.4`=16px,
`space.8`=32px). `/design-verify`s `tokens`-Stufe erkennt Rohwerte
außerhalb dieser Skala.

## Radien, Schatten, Bewegung

Kurz — nur so viele Stufen, wie das Projekt tatsächlich braucht. YAGNI gilt
auch hier: eine Elevation-Skala mit acht Stufen für ein werkzeugartiges
Dashboard ist Overhead, keine Sorgfalt.

## Komponenteninventar

Für jede wiederkehrende Komponente (Button, Dropdown, Tabelle, Karte,
Toast, …): Zustände (default/hover/focus/disabled/loading/error, soweit
zutreffend), Mindestgröße der Trefferfläche, wann sie verwendet wird und
wann nicht.

## Copy- und Tonalitätsregeln

Anrede (du/Sie), Ton (knapp/erklärend), Umgang mit Fehlermeldungen
(technisch vs. handlungsorientiert), Datums-/Zahlenformat.

## Accessibility-Untergrenze

Kontrastverhältnis (mindestens WCAG AA, 4.5:1 für Fließtext), sichtbarer
Fokusring, Mindestgröße von Trefferflächen (44×44px als Richtwert).

## Do-not-Liste

Explizit ausgeschlossene Muster — meist direkt aus Phase 1, Frage 4
übernommen. Genauso wichtig wie die Vorgaben selbst.

## Was hier NICHT hingehört

Ein Abschnitt „Bekannte Lücke von /design-verify" oder Ähnliches. Eine
Grenze des Plugins wird im Plugin behoben (siehe SKILL.md), nicht im
Design-System des Projekts festgehalten.

