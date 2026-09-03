# `/design-split`: Screens auf Teil-Specs aufteilen

Ein Manifest pro Projekt, niemals geteilt. Geteilt wird nur die Zuordnung
über `allocations:` im Manifest.

## Ablauf

1. Manifest und die Eltern-Spec (bzw. die geplante Dekomposition aus
   `superpowers:writing-plans`) lesen.
2. Zuordnungstabelle Teil-Spec ↔ Screens vorschlagen — jeder Screen genau
   einer Teil-Spec zugeordnet (`owns`). Dem User zeigen, Genehmigung
   einholen, bevor irgendetwas geschrieben wird.
3. Elemente ermitteln, die über `uses:` von mehr als einer Teil-Spec
   referenziert werden. Für jedes: die besitzende Spec (dort, wo das Element
   im Manifest unter dem `owns`-Screen steht) trägt es in ihre `screens=`,
   alle konsumierenden Specs tragen seine ID in `consumes=`.
4. `allocations:` ins Manifest schreiben:

   ```yaml
   allocations:
     - spec: docs/superpowers/specs/2026-09-03-orders-design.md
       owns: [UI-ORDERS, UI-SHELL]
       consumes: []
     - spec: docs/superpowers/specs/2026-09-04-order-detail-design.md
       owns: [UI-ORDER-DETAIL]
       consumes: [UI-SHELL-NAV]
   ```

   `revision` erhöhen, `changelog`-Eintrag mit den betroffenen `touched`-IDs.
5. Für jede Teil-Spec `carrying-design-through` im `mode=spec` ausführen,
   mit `--screens` auf deren `owns`-Liste beschränkt und `--consumes` auf
   die in Schritt 3 ermittelten IDs.

## Zwei Fälle von „Element in mehreren Teil-Specs"

- **Dasselbe Element, mehrfach verwendet** (Navigation, Toast, ein globaler
  Fehlerbanner): eine ID, genau ein `owns`, überall sonst `consumes`. In der
  besitzenden Spec steht es in der **Tabelle** (`## UI Requirements`), in
  den konsumierenden Specs nur in der **Prosaliste** „Übernommene Elemente".
  Kein Tabellenstatus `reference`: preflight Stage 1 liest Tabellenzeilen
  als zu deckende Anforderungen und würde für eine fremd gebaute Navigation
  sonst einen falschen Blocker melden, weil die konsumierende Spec sie nie
  selbst baut.
- **Ähnliches Element, zweimal gebaut** (z. B. dieselbe Navigation für Web
  und für eine TUI-Variante): zwei eigenständige IDs mit `variant_of:` im
  Manifest, jede mit eigenem `owns`. Nie ein Element in zwei Specs mit zwei
  unterschiedlichen Implementierungen unter derselben ID — sonst ist
  unentscheidbar, welche Implementierung das Manifest eigentlich meint.

## Invarianten (`/design-check` prüft diese automatisch)

- Jeder Screen ist mindestens einer `allocations`-Zeile zugeordnet.
- Jedes Element hat projektweit genau einen Owner (die Spec, deren
  `owns`-Liste den Screen enthält, unter dem das Element im Manifest steht).
- Jede zugeordnete Spec-Datei existiert und trägt einen Design-Block, dessen
  `screens=` exakt der `owns`-Liste entspricht.
- Jeder Block trägt `manifest=`, `system=`, `index=` — unabhängig von der
  Zuordnung (siehe `spec-block.md`).
- `design_rev` jedes Blocks ist ≤ der aktuellen Manifest-`revision`.
