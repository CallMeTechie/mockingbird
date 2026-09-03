# Stage: `states` — Zustände

**Dein Mandat ist ausschließlich diese Stage. Beratend — nie verdikt-
wirksam** (siehe `coverage-rules.md`, Regel 5): Zustände werden in einem
Inkrement legitim vertagt, ein blockierendes Verdikt darauf wäre ein
Dauerärgernis.

## Die Frage

Ist für jedes zugewiesene Element jeder im Manifest deklarierte Zustand
(`states[]`, z. B. `loading`, `empty`, `error`) im Code als eigener Branch
vorhanden — nicht notwendigerweise perfekt umgesetzt, aber vorhanden?

## Vorgehen

Grep nach den üblichen Mustern für den jeweiligen Zustand (Loading-Flag,
bedingtes Rendering für leere Listen, Error-Boundary/Catch-Block). Ein
fehlender Branch ist leicht zu finden und billig zu prüfen — das ist der
Grund, warum diese Stage trotz „nur beratend" trotzdem läuft.

## Ausgabeformat

```
MB-COVERAGE
<element-id> | states | ok|partial|violated|unverified:<reason> | <file:line|->
END
```

`ok` = alle deklarierten Zustände als Branch vorhanden. `partial` = einige
vorhanden, andere fehlen (im Bericht nennen, welche). `violated` = ein
Zustand ist vorhanden, tut aber nachweislich das Falsche (z. B. der
Error-Zustand zeigt den Loading-Text). `unverified:no-locator` = das
Element selbst nicht gefunden (Coverage-Regel 6 greift dann ohnehin über
`structure`).
