---
description: Read-only — checks the manifest and every derived document against the mockingbird invariants.
argument-hint: "[--root DIR] [project root, default: current project]"
---

Read-only. Schreibt nichts.

Zuerst den deterministischen Teil laufen lassen — er deckt Schritte 1–4
vollständig ab und gibt `Befund | Ort | Schwere`-Zeilen aus:

```
${CLAUDE_PLUGIN_ROOT}/scripts/mb-design-check.sh <projekt-root>
```

Die Schritte im Detail (was das Skript prüft):

1. `docs/design/manifest.yaml` validieren:
   `${CLAUDE_PLUGIN_ROOT}/lib/mockingbird-manifestlib.sh` → `mb_manifest_validate`
   mit `MB_VALIDATE_ROOT` gesetzt.
2. Für jede Spec unter `docs/superpowers/specs/*-design.md`, die einen
   `mockingbird:design`-Block trägt: `design_hash`/`design_rev` gegen das
   aktuelle Manifest prüfen (siehe `plugin/hooks/mockingbird-hooklib.sh`,
   `mb_design_hash` und `mb_stale_docs`).
3. Split-Invarianten prüfen (nur falls `allocations:` im Manifest steht,
   siehe `carrying-design-through/references/splitting.md`, Abschnitt
   „Invarianten"):
   - jeder Screen in mindestens einer `allocations`-Zeile
   - jedes Element hat genau einen Owner
   - jede zugeordnete Spec existiert und ihr Block-`screens=` entspricht der
     `owns`-Liste
   - jeder Block trägt `manifest=`, `system=`, `index=`
   - `design_rev` jedes Blocks ≤ aktuelle Manifest-`revision`
4. Für jeden zugehörigen Plan: prüfen, ob jeder Task entweder eine
   Design-Tabelle (Kanal C) oder die Zeile `**Design:** kein UI-Anteil.`
   trägt — ein Task ohne beides wird gemeldet.
5. Bericht als Tabelle `Befund | Ort | Schwere`. Nichts anwenden, nichts
   fixen — dafür ist `/design-sync` bzw. `/design-verify` da.

**Projektverzeichnis:** `--root DIR` legt das Projekt fest (das Verzeichnis mit `docs/design/`). Ohne `--root` gilt das aktuelle Arbeitsverzeichnis bzw. dessen Projekt-Root. So lässt sich ein anderes Projekt bearbeiten, ohne die Session dort zu starten.
