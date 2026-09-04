---
description: Work out a frontend design with the user and write docs/design/ — design system, HTML artboards and the machine-readable manifest.
argument-hint: "[--root DIR] [--extend] [--adapter web|tui|desktop|mobile]"
allowed-tools: AskUserQuestion, Read, Write, Edit, Glob, Grep, Bash, Task
---

Rufe das Skill `designing-frontends` (mockingbird) auf.

Argumente: `$ARGUMENTS`.
- `--extend`: `docs/design/manifest.yaml` existiert bereits — Phase 0
  entsprechend im Erweiterungspfad starten, bestehende IDs nie umbenennen.
- `--adapter <name>`: Zielmedium vorgeben statt in Phase 0 zu fragen.

Folge dem Skill exakt in seiner Phasenreihenfolge (0 Medium/Bestand →
1 Referenzen → 2 Inventar → 3 Design-System → 4 Artboards → 5 Manifest →
6 Approval-Gate → 7 Übergabe). Schreibe nichts in eine Spec — das ist
`/design-spec`.

**Projektverzeichnis:** `--root DIR` legt das Projekt fest (das Verzeichnis mit `docs/design/`). Ohne `--root` gilt das aktuelle Arbeitsverzeichnis bzw. dessen Projekt-Root. So lässt sich ein anderes Projekt bearbeiten, ohne die Session dort zu starten.
