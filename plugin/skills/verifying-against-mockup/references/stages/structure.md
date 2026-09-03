# Stage: `structure` — Existenz, Gruppierung, Reihenfolge

**Dein Mandat ist ausschließlich diese Stage.**

## Die Frage

Existiert jedes zugewiesene Manifest-Element im Code, unter dem richtigen
Screen, in ungefähr der im Manifest impliziten Reihenfolge? Dies ist das
Coverage-Rückgrat: Elemente, die hier fehlen, dürfen sich in keiner anderen
Stage hinter „nicht gefunden" verstecken.

## Vorgehen

Für jedes zugewiesene Element: `mockingbird-scope.sh --locate <element-id>
--root <projekt>` nutzen, um Kandidaten mit Tier zu bekommen. Tier A/B
zählt als gefunden. Nur Tier C (Namenskonvention, kein Label-/ID-Treffer):
melde es, aber als schwach belegt — das Coverage-Regelwerk deckelt Tier-C-
Befunde bereits (siehe `coverage-rules.md`).

Prüfe zusätzlich, wo im Code die gefundenen Elemente eines Screens
zueinander stehen, gegen die Reihenfolge im Manifest (Elemente sind dort in
der beabsichtigten Reihenfolge aufgeführt). Eine vertauschte Reihenfolge ist
ein `partial`, kein `violated` — sie ändert nichts an der Bedeutung eines
einzelnen Elements.

## Ausgabeformat

```
MB-COVERAGE
<element-id> | structure | ok|partial|violated|unverified:<reason> | <file:line|->
END
```

`ok` = gefunden, Tier A/B, plausible Position. `partial` = gefunden, aber
Tier C oder falsche Reihenfolge. `violated` = **nur** wenn das Element durch
etwas anderes ersetzt wurde, das eindeutig nicht dasselbe ist (selten in
dieser Stage — meist ist „nicht gefunden" `unverified:no-locator`, nicht
`violated`; für `violated` brauchst du wie überall ein belegtes
`file:line`, das die Ersetzung zeigt). `unverified:no-locator` = keine
Spur des Elements gefunden.
