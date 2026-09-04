---
description: Record which sub-spec owns which screens when a spec is decomposed into several specs.
argument-hint: "[--root DIR] spec1=ID,ID spec2=ID,ID ..."
---

Rufe das Skill `carrying-design-through` (mockingbird) mit `mode=split` auf.
Vollständiger Ablauf: `carrying-design-through/references/splitting.md`.

Argumente: `$ARGUMENTS` = Paare `<spec-pfad>=<Screen-ID>,<Screen-ID>,...`,
eines je Teil-Spec. Fehlen sie, die Zuordnung im Dialog mit dem User
vorschlagen (basierend auf der laufenden Dekomposition), zeigen und
genehmigen lassen — **vor** jedem Schreiben.

Schreibe niemals `allocations:` ohne explizite Zustimmung des Users zur
vorgeschlagenen Zuordnungstabelle.

**Projektverzeichnis:** `--root DIR` legt das Projekt fest (das Verzeichnis mit `docs/design/`). Ohne `--root` gilt das aktuelle Arbeitsverzeichnis bzw. dessen Projekt-Root. So lässt sich ein anderes Projekt bearbeiten, ohne die Session dort zu starten.
