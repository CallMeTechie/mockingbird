---
description: Checks the built code against docs/design/manifest.yaml — including whether a control's data binding actually matches its label — applies provable fixes, and reports a MATCH/MISMATCH verdict.
argument-hint: "[--root DIR] [--screen ID] [--since REF] [--fix] [--level blocker|important]"
---

Rufe das Skill `verifying-against-mockup` (mockingbird) auf, `mode=fix`
falls `--fix` gesetzt ist, sonst `mode=verify`.

Argumente: `$ARGUMENTS`.
- Ohne `--screen`: Scope aus `mockingbird-scope.sh --scope [--since REF]`
  bestimmen (siehe Skill, Schritt 2).
- `--fix`: Fixes nach `fix-policy.md` anwenden (Schritt 6), sonst nur
  Bericht.
- `--level`: wirkt nur auf die **Anzeige**, nie auf das Verdikt (siehe
  `coverage-rules.md`).

Folge dem Skill exakt in seiner Schrittfolge (Lock → Gate → Fan-out →
Seam-Check → Konsolidierung → [Fixes] → State/Freigabe).

**Projektverzeichnis:** `--root DIR` legt das Projekt fest (das Verzeichnis mit `docs/design/`). Ohne `--root` gilt das aktuelle Arbeitsverzeichnis bzw. dessen Projekt-Root. So lässt sich ein anderes Projekt bearbeiten, ohne die Session dort zu starten.
