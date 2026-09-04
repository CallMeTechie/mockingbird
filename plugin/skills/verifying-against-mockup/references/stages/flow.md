# Stage: `flow` — Aktionen und Navigation

**Dein Mandat ist ausschließlich diese Stage.** Gleiche Technik wie
`semantic` (eine Kette mit Beleg verfolgen), anderer Fehlermodus: ein toter
Button statt einer falschen Datenquelle.

## Die Frage

Ist jedes Element vom Typ `action` (oder ein interaktives Element mit
Zielangabe im Manifest, z. B. ein `flows:`-Eintrag) tatsächlich verdrahtet
— und führt es zum im Manifest genannten Ziel, nicht zu einem anderen oder
zu keinem?

## Vorgehen

Für jedes zugewiesene `action`-Element: Handler finden (`onClick`,
Route-Push, Formular-Submit, …), Ziel verfolgen (Route, Modal, API-Call),
mit dem Manifest-Ziel abgleichen (`flows:` im Manifest, oder implizit aus
dem Element-Kontext). Ein Button ohne jeden Handler ist der häufigste
Treffer dieser Stage — leicht und verlässlich zu finden.

## Ausgabeformat

```
MB-SEAM
<element-id> | tier=A|B|C | render=<f:l|-> | binding=<f:l|-> | source=- | handler=<f:l|-> | terminal=<f:l|-> | found=<ziel> | ok|partial|violated|unverified:<reason>
END
```

`source` bleibt bei dieser Stage meist `-` (keine Datenquelle relevant).
`terminal` ist hier das tatsächliche Sprungziel (Route/Modal-ID/Endpoint).
Gleiche vier Urteilsklassen und dieselbe Beweislast wie bei `semantic` —
kein `violated` ohne belegtes `terminal`, kein Tier-C-`violated`.

## Ein angeführter Beleg muss greifen können

Führst du eine CSS-Regel, eine Konfiguration oder eine Bedingung als Beleg
**oder** als Gegenbeleg an, prüfe zuerst, ob sie zur Laufzeit überhaupt
wirken kann: welchen Elternselektor sie hat, ob die genannte Klasse real
gerendert wird, ob der verlangte Vorfahre im echten DOM existiert. Achtung
bei `createPortal` und Teleport-Mechanismen — sie verschieben den echten
DOM nicht, ein Nachfahren-Selektor über die Portal-Grenze greift nie. Wo es
ein gebautes Artefakt gibt (`dist/`), ist der Blick hinein der billigste
Beweis. Eine Regel, die vorhanden aussieht, aber nie greift, ist der
gefährlichste Beleg: sie besteht den Seam-Check, weil ihr `file:line`
existiert.
