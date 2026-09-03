---
description: Refresh the design block in a spec, plus the plan header, global constraints and per-task design tables when they drifted.
argument-hint: "[path to spec or plan]"
---

Rufe das Skill `carrying-design-through` (mockingbird) mit `mode=sync` auf,
gefolgt von `mode=plan` für den zugehörigen Plan, falls vorhanden.

Argumente: `$ARGUMENTS` = optionaler Pfad. Ohne Pfad: alle Dateien, die laut
`<project>/.claude/.mockingbird-synced` gegen die aktuelle
`docs/design/`-Prüfsumme veraltet sind (siehe
`plugin/hooks/mockingbird-hooklib.sh`, `mb_stale_docs`).

Ablauf:
1. Für jede zu synchronisierende Spec: Skill mit `mode=sync` ausführen.
2. Hat sich dabei `screens=` oder `consumes=` im Block geändert, den
   zugehörigen Plan (per `**Spec:**`-Zeile oder Dateiname/Themen-Heuristik
   auflösen, wie `subagent-driven-development` es tut) ebenfalls mit
   `mode=plan` aktualisieren.
3. Zusammenfassen, was aktualisiert wurde und was bereits aktuell war
   (Exit 4 aus `mb-insert-block.sh` — kein Grund zur Sorge, kein Fehler).
