---
name: designing-frontends
description: Use when a project needs a user interface and no design exists yet, or when the user talks about screens, layouts, mockups, look and feel, or asks to change how something looks — works out the design in dialogue with the user, then writes docs/design/design-system.md, HTML artboards and a machine-readable manifest.yaml before any spec is written.
---

# Frontend-Design im Dialog erarbeiten

## Overview

UI/UX-Design wird bei agentischer Entwicklung meist übersprungen oder geht
über die Projektdauer verloren, weil es nirgends festgeschrieben ist. Dieses
Skill füllt genau diese Lücke: es fragt nach Vorbildern statt zu raten,
erarbeitet ein Design-System, zeichnet HTML-Artboards und destilliert daraus
ein maschinenlesbares Manifest — bevor irgendeine Spec geschrieben wird.

**Ergebnis:** `docs/design/design-system.md`, `docs/design/mockups/*.html`
(+ `tokens.css`, `index.html`), `docs/design/manifest.yaml`. Format und
Vertrag: `references/manifest-schema.md`.

## Einordnung gegenüber superpowers:brainstorming

`superpowers:brainstorming` erlaubt auf dem architektonischen Pfad nach dem
Design-Dokument **ausschließlich** `writing-plans` als nächsten Schritt —
"the ONLY skill you invoke after brainstorming is writing-plans". Dieses
Skill ersetzt das nicht und wird niemals danach aufgerufen.

Stattdessen zwei legitime Einstiege:

1. **Bevorzugt: `/design` als eigener, vorgelagerter Schritt**, bevor oder
   unabhängig vom Brainstorming einer Spec.
2. **Eingebettet in den Brainstorming-Fluss**, zwischen dessen Checkliste-
   Schritt 5 (Present design) und Schritt 6 (Write design doc): sobald die
   UI-Anteile des Designs klar sind, aber bevor die Spec geschrieben wird.

Der sachliche Grund für „davor": die Spec referenziert Manifest,
Design-System und Artboard-Index als Dateipfade. Existieren sie beim
Schreiben der Spec noch nicht, meldet der preflight-Factchecker sie als
`missing`. Die Artefakte **müssen** vor der Spec entstehen.

## Ablauf

Der ganze Dialog läuft im **Main-Thread**, nicht in einem Subagenten:
`AskUserQuestion` steht Subagents nicht zur Verfügung.

### Phase 0 — Medium und Bestand

Frage, welches Medium gestaltet wird (Web, TUI, Desktop, Mobile, gemischt) —
nicht raten, das bestimmt den Adapter im Manifest. Existiert bereits
`docs/design/manifest.yaml`, in den `--extend`-Pfad wechseln: neue Screens
bekommen neue IDs, bestehende IDs bleiben unverändert (siehe
`manifest-schema.md`, „IDs werden nie umbenannt").

### Phase 1 — Referenzen

Der Kern der Anforderung: nach Beispielen fragen, statt bei Null anzufangen.
Fragenreihenfolge und Fallback-Archetypen: `references/reference-intake.md`.
Höchstens sechs Fragen, bevor etwas Sichtbares entsteht.

### Phase 2 — Inventar

Screens und ihre Elemente als **Liste**, noch ohne Artboards — billig zu
korrigieren, bevor Zeit in Zeichnung fließt. Hier werden die IDs nach der
Grammatik aus `references/manifest-schema.md` vergeben. Nicken abholen:
„Sind das die Screens? Fehlt einer?"

### Phase 3 — Design-System zuerst

`docs/design/design-system.md` aus `references/design-system-template.md`
füllen: Farbrollen, Typo-Skala, Abstandsskala, Radien, Elevation, Motion,
Komponenteninventar mit Zuständen, Copy-/Tonalitätsregeln,
Accessibility-Untergrenze (Kontrast, Fokus, Trefferflächen), eine
„Do not"-Liste. Parallel `docs/design/mockups/tokens.css` erzeugen. Beides
im Chat zur Genehmigung zeigen, bevor Artboards davon abhängen.

### Phase 4 — Artboards

**Zuerst den Manifest-Entwurf schreiben** (Phase 5 vorziehen, noch ohne
Freigabe der Anker): der Artboard-Writer braucht Elemente, Zustände und
Beispielwerte als Manifest-Ausschnitt, und `--validate` fängt Subset-Fehler,
bevor vier Artboards darauf aufbauen. Erst dann je Screen
`docs/design/mockups/<slug>.html`, plus `index.html` als Kontaktbogen (alle
Screens nebeneinander) — den Kontaktbogen schreibt der Main-Thread, nicht die
parallelen Writer, sonst überschreiben sie sich gegenseitig.
(Reihenfolge korrigiert nach dem ersten Live-Dialog am 2026-09-03.) Konventionen — Locator-Attribute,
Zustands-Rendering, realistische Inhalte statt Lorem Ipsum, kein Build, kein
CDN — in `references/artboard-conventions.md`. Mechanisch und
tokenintensiv: an `mockingbird:artboard-writer` delegieren (siehe unten).
Der Dialog selbst bleibt im Main-Thread.

### Phase 4b — Kontaktbogen

`${CLAUDE_PLUGIN_ROOT}/scripts/mb-render-index.sh --root <projekt>` erzeugt
`docs/design/mockups/index.html`: je Screen Art und Darstellungskontext,
Zweck, Elementtabelle mit fachlichen Ankern, Zustände, Link zum Artboard
und zur Umsetzungsanleitung — und darunter das Artboard selbst als
eingebetteter, stil-gekapselter Auszug. Keine `<iframe>`s: die sind über
`file://` oft leer und erklären nichts (Rückmeldung aus dem ersten
Live-Dialog).

### Phase 5 — Manifest

`docs/design/manifest.yaml` gemäß `references/manifest-schema.md` füllen —
**in der dort unter „Schreibform" festgelegten Form** (Flow-Style-States,
Inline-Listen; Blockskalare `>`/`|` sind erlaubt): der Parser verweigert alles
andere mit Exit 5. Nach dem Schreiben sofort
`${CLAUDE_PLUGIN_ROOT}/scripts/mockingbird-scope.sh --validate --root <projekt>`
laufen lassen und Fehler beheben, bevor es weitergeht.
Die semantischen Anker (`means`, `concept`, `aliases`, `not`) sind der
mühsamste, aber wichtigste Teil — sie sind später die einzige Grundlage,
auf der `/design-verify` beurteilen kann, ob ein Dropdown „Abteilung"
wirklich Abteilungen zeigt. Was aus den bisherigen Antworten ableitbar ist,
wird abgeleitet und mit Beleg gezeigt; was nicht ableitbar ist, wird
**gefragt, nie geraten**. Fragen bündeln, bis zu vier pro Runde.

### Phase 6 — Approval-Gate

**Vor jedem Schreiben in eine Spec** — nicht vor dem Schreiben des Manifests
selbst, das gehört zum iterativen Entwurf. Gezeigt werden: Screenliste,
Pfad zum Artboard-Index, Token-Tabelle, und die UI-Requirements-Tabelle
exakt so, wie `carrying-design-through` sie in die Spec rendern würde —
`${CLAUDE_PLUGIN_ROOT}/scripts/mb-render-block.sh --root <projekt>` schreibt
nichts, es gibt den Block nur auf stdout aus, ist also selbst schon die
Vorschau. Bei Zustimmung: `revision` erhöhen, `changelog`-Eintrag mit
`touched`, Manifest final schreiben.

### Phase 6b — Umsetzungsanleitungen

Nach der Freigabe je Screen `docs/design/guides/<screen-slug>.md` schreiben,
nach `references/implementation-guide-template.md`: explizite Anweisungen
an die KI, wie dieses Mockup in Produktivcode übergeht — welche Datei,
welche vorhandene Komponente, wo das `data-ui-id` hin muss, welche Zustände
in welchem Branch, welche Tokens, was ausdrücklich nicht. Das ist das zweite
Artefakt neben dem Artboard, das durch Spec, Plan und Task-Brief getragen
wird (`carrying-design-through`, Kanal C nennt es je Task). Der Pfad steht
im Manifest als `guide:` am Screen.

### Phase 7 — Übergabe

Genau eine nächste Aktion nennen, kein Menü — typischerweise
`superpowers:brainstorming` (falls noch keine Spec existiert) oder
`/design-spec` (falls die Spec schon geschrieben ist und nur der
Design-Block fehlt).

## Iteration

Jedes „nein" springt in die Phase, der der Einwand gehört (Tokens → Phase 3,
Screens → Phase 2, Wortlaut → Phase 5); nur die betroffenen Artboards werden
neu erzeugt, nicht alle.

## Fallback ohne Vorbilder

Kommen in Phase 1 keine Referenzen, nie bei Null anfangen — drei benannte
Archetypen anbieten (siehe `references/reference-intake.md`):
**werkzeugartig** (dicht, tabellenlastig, tastaturgetrieben), **großzügig**
(viel Weißraum, starke Typografie, wenige Elemente pro Screen),
**dokumentartig** (lesbarkeitsgetrieben, eine Spalte, ruhige Farben).

## Der `artboard-writer`-Agent

Phase 4 delegiert an `mockingbird:artboard-writer` (`tools: Read, Write,
Edit, Glob, Bash`, `model: sonnet`). Der Dispatch bekommt: den Manifest-
Ausschnitt für genau einen Screen, `design-system.md`, `tokens.css`-Pfad,
und die Konventionen aus `references/artboard-conventions.md` (nur den
relevanten Abschnitt zitieren, nicht die ganze Datei). Der Agent schreibt
ausschließlich unter `docs/design/mockups/`. Nach jedem Dispatch das
Ergebnis kurz gegenlesen — insbesondere: trägt jedes Element ein
`data-ui-id`, ist jeder deklarierte Zustand als eigener, beschrifteter
Abschnitt vorhanden.

## Behebbare Grenzen werden behoben, nicht gemeldet

Stößt dieses Skill auf eine Grenze des Plugins, die sich mit vertretbarem
Aufwand beheben lässt — ein Adapter, der einen Dateityp nicht sieht; ein
Parser-Subset, das eine gebräuchliche Schreibweise ablehnt; ein Locator, der
ein übliches Muster nicht kennt — dann wird sie **im Plugin behoben**: Code,
Test, Commit, ein Satz im Bericht. Nicht als „bekannte Lücke" in das Projekt
des Users schreiben, nicht fragen, ob man soll. Rückfrage nur, wenn die
Behebung eine Design-Entscheidung des Users berührt oder das Verhalten für
andere Projekte spürbar ändert. (Regel des Users vom 2026-09-04.)
