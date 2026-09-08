# Umsetzungsanleitung — Vorlage (Phase 6b)

Je Screen eine Datei `docs/design/guides/<screen-slug>.md`, im Manifest am
Screen als `guide:` eingetragen. Sie ist das zweite Artefakt neben dem
Artboard, das `carrying-design-through` durch Spec, Plan und Task-Brief
trägt (Kanal C nennt sie je Task).

## Wofür sie da ist

Das Artboard zeigt, **wie** es aussieht. Das Manifest sagt, **was** ein
Element bedeutet. Die Anleitung sagt, **wo im Produktivcode** das hingeht:
welche Datei, welche vorhandene Komponente, wo das `data-ui-id` sitzt,
welcher Zustand in welchem Branch, welche Tokens — und was ausdrücklich
nicht gebaut wird.

## Die eine Regel, die zuerst gilt

**Die Anleitung darf nie mehr fordern als das Manifest.** Jede Aussage über
Bedeutung, Zustände oder Beschriftungen ist aus dem Manifest abgeleitet, nie
dazuerfunden. Was in der Anleitung steht, aber nicht im Manifest, ist für
`/design-verify` unsichtbar und wird zu einer Anforderung, die niemand prüft.
Fällt beim Schreiben auf, dass etwas fehlt, gehört es ins Manifest — dann
hierher, nicht umgekehrt.

Zweite Regel: **nichts raten.** Dateipfade, Komponentennamen und
Bestandsverhalten werden vor dem Schreiben im Code nachgesehen. Eine
erfundene Zeilennummer oder ein Bestandsmenü aus dem Gedächtnis kostet
später mehr, als das Nachsehen gekostet hätte.

## Aufbau

```markdown
# <Screen-Titel> — Umsetzungsanleitung (<UI-SCREEN>)

Artboard: docs/design/mockups/<slug>.html · Manifest-Revision: <rev>

<Ein bis drei Sätze: Gibt es diesen Screen schon? Was ist neu, was ist
Bestand? Was wird ausdrücklich nicht neu gebaut?>

## Wo im Code
- <Pfad> — welche Element-IDs hier hängen
- <Pfad> — **neu**, wenn eine Datei erst entsteht
- Wiederverwenden: <Bestandskomponenten aus common/components>
- Styles: <wo>, Werte aus <Token-Definitionsdateien>

## Darstellung
- Art (page/dialog/panel/…), Auslöser, Größe, Schließen — aus `presentation:`
- Aufbau von oben nach unten
- Tastatur
- Wo der Screen NICHT erscheint (Provider, Fähigkeit, Breakpoint)

## Elemente — eins nach dem anderen
### <UI-SCREEN-ELEM> — <Beschriftung> (neu | Bestand)
- `data-ui-id="<ID>"` an <genau welchem Knoten> — genau einmal.
- Datenquelle: <Endpunkt/Feld>. Muss <X> liefern, **nicht** <die Nachbarn
  aus semantic_anchor.not>.
- Zustände: je deklariertem Zustand ein Satz, `copy:` wörtlich.
- Tokens: welche, wofür.

## Ausdrücklich nicht
<Was naheliegt, aber falsch wäre — aus der Do-not-Liste des Design-Systems
und aus `semantic_anchor.not`.>

## i18n
<Neue Schlüssel, im Namensschema des Bestands. Welche Sprachdatei zuerst.>
```

## Abschnitte, die entfallen dürfen

`i18n` bei einem Projekt ohne Übersetzung, `Ausdrücklich nicht` bei einem
Screen ohne naheliegende Fehldeutung. Alles andere bleibt: „Wo im Code" und
der Elementteil sind der Zweck der Datei.

## Länge

So lang wie nötig, selten über 120 Zeilen. Sie wird von einem Agenten
gelesen, der den Screen baut — nicht von einem Menschen, der sich
einarbeitet. Prosa über Motivation gehört ins Design-System, nicht hierher.
