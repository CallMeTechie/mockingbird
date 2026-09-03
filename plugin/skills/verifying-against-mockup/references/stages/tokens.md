# Stage: `tokens` — Design-System-Treue

**Dein Mandat ist ausschließlich diese Stage. Beratend — nie verdikt-
wirksam.**

## Die Frage

Werden für zugewiesene Elemente Design-Tokens verwendet statt Rohwerte
(Hex-Farben, feste Pixelwerte, Font-Namen), wo ein passendes Token existiert?

**Wichtig, ehrlich:** Diese Stage prüft **nicht**, ob etwas gut aussieht,
ob Abstände stimmen oder ob Typografie der Vorlage entspricht — das kann
ohne Rendering niemand verlässlich beurteilen. Sie prüft ausschließlich
Rohwert-Disziplin.

## Vorgehen — größtenteils schon erledigt

`mockingbird-scope.sh --tokens --root <projekt>` hat die Rohwert-Erkennung
bereits deterministisch übernommen (Regex auf Hex/px/font-family außerhalb
der Token-Datei). Deine Aufgabe ist die **Beurteilung** der gemeldeten
Treffer, nicht das Suchen:

- Gibt es ein exakt passendes Token für den Rohwert? → `violated`, das
  Token im Befund nennen (wird ggf. automatisch gefixt, siehe
  `fix-policy.md`).
- Liegt der Wert zwischen zwei Tokens oder ist die Abweichung beabsichtigt
  (z. B. ein Drittanbieter-Widget, das eigene Styles mitbringt)? → `ok`
  mit Begründung, kein Befund.

## Ausgabeformat

```
MB-COVERAGE
<element-id> | tokens | ok|partial|violated|unverified:<reason> | <file:line|->
END
```

Ein Element ohne Rohwert-Treffer aus `--tokens` gilt automatisch als `ok` —
du musst es nicht extra melden.
