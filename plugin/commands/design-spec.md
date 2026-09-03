---
description: Render the mockingbird design block into a superpowers spec from docs/design/manifest.yaml.
argument-hint: "[path to spec] [--screens ID,ID,...] [--consumes ID,ID,...]"
---

Rufe das Skill `carrying-design-through` (mockingbird) mit `mode=spec` auf.

Argumente: `$ARGUMENTS` = optionaler Pfad zur Spec-Datei, optional
`--screens ID,ID,...` und `--consumes ID,ID,...`.

- Ohne Pfad: die zuletzt geänderte Datei unter `docs/superpowers/specs/`, die
  auf `-design.md` endet. Existiert das Verzeichnis nicht oder passt keine
  Datei, abbrechen und nach einem expliziten Pfad fragen.
- Ohne `--screens`: alle Screens im Manifest (Ein-Spec-Fall, vor jedem
  `/design-split`).
- Ohne `--consumes`: dieses Skript leitet die Liste nicht selbst ab (der
  strikte Manifest-Parser parst `uses:` bewusst nicht). Lies `uses:` der
  betroffenen Screens im Manifest von Hand und bilde daraus die Liste, wie
  in `carrying-design-through/SKILL.md` (`mode=spec`, Schritt 3) beschrieben.

Folge dem Skill exakt in der dort beschriebenen Reihenfolge (Manifest lesen →
Screens/Consumes bestimmen → `mb-insert-block.sh` ausführen → Ergebnis
zusammenfassen).
