---
name: carrying-design-through
description: Use when a superpowers spec or plan is written or changed while docs/design/manifest.yaml exists — writes and refreshes the design block in the spec, the design header and global constraints in the plan, the per-task design tables, and the screen allocation when a spec is split. Invoked by the mockingbird PostToolUse hook (advisory) or the /design-spec, /design-sync and /design-split commands.
---

# Design durch Spec, Plan und Task-Brief tragen

## Overview

Ein Manifest in `docs/design/manifest.yaml` ist wertlos, wenn es beim Bauen
niemand mehr sieht. Dieses Skill schreibt und aktualisiert die vier Stellen,
über die das Design den Weg vom Manifest bis in den Task-Brief eines
Implementer-Subagents überlebt — und nur diese vier, da genau sie
nachweislich erreicht werden (siehe `references/plan-propagation.md`, Test
`tests/run-plan-propagation-tests.sh` gegen das echte `task-brief`-awk aus
superpowers).

**Input:** `mode` (`spec` | `sync` | `plan` | `split`) + `path` zur Datei.
Quelle: Hook-Hinweis oder Command-Argument.

## Wann dieses Skill NICHT reicht

- Es schreibt niemals `docs/design/manifest.yaml` selbst — das Manifest
  entsteht ausschließlich im Dialog über `designing-frontends`. Dieses Skill
  liest das Manifest nur.
- Es ist kein Ersatz für `superpowers:writing-plans` oder
  `superpowers:brainstorming` — es läuft daneben, nicht anstelle davon.

## Die vier Kanäle (Kurzreferenz)

| Kanal | Ort | Erreicht | Details |
|---|---|---|---|
| A | Plan-Header, nach `**Spec:**` | Controller, preflight, Menschen — **nicht** den Implementer | `references/plan-propagation.md` |
| B | `## Global Constraints` | Implementer *und* Task-Reviewer (über dessen `[GLOBAL_CONSTRAINTS]`-Platzhalter) | `references/plan-propagation.md` |
| C | Innerhalb von `### Task N`, nach `**Interfaces:**` | **Der Implementer** — der einzige Kanal, der den `task-brief`-Schnitt überlebt | `references/plan-propagation.md` |
| D | `DESIGN-COVERAGE`-Block | preflight Stage 1 (Requirements-Coverage) automatisch, die mockingbird-Verify-Kette gezielt | `references/plan-propagation.md` |

Kanal C ist der einzige, der einen Implementer-Subagenten erreicht.
`scripts/task-brief` schneidet ausschließlich den Block von
`^#+[ \t]+Task[ \t]+N` bis zur nächsten Task-Überschrift heraus — Header,
`**Spec:**`-Zeile und `## Global Constraints` sind darin **nicht** enthalten.

## Ablauf nach `mode`

### `mode=spec`

Der Design-Block wird in eine Spec geschrieben oder aktualisiert.

1. Manifest lesen: `docs/design/manifest.yaml`. Existiert es nicht, abbrechen
   und auf `/design` verweisen.
2. Screens dieser Spec bestimmen. Ohne vorherige `/design-split`-Zuordnung
   deckt eine Spec das ganze Manifest ab — kein `--screens`-Filter.
   Mit Zuordnung (`allocations:` im Manifest, von `/design-split` gepflegt):
   nur die `owns`-Screens dieser Spec.
3. Nichts von Hand ableiten: `--spec <repo-relativer Spec-Pfad>` mitgeben.
   Steht die Spec in `allocations:`, liefern deren `owns`/`consumes` die
   Screens; sonst gelten alle Screens, und die übernommenen Elemente werden
   aus den `uses:`-Listen der Screens automatisch bestimmt. Explizite
   `--screens`/`--consumes` überschreiben beides.
4. `${CLAUDE_PLUGIN_ROOT}/scripts/mb-insert-block.sh <spec-pfad> --root <projekt-root> --spec <spec-pfad-relativ>` ausführen.
   - Exit 0: geschrieben. Exit 4: schon aktuell, nichts zu tun.
   - Exit 2/3/6: Fehler lesen und beheben (Usage, fehlende Datei,
     Manifest-Validierung) — niemals den Block von Hand nachbauen.
5. Kurz bestätigen, was geschrieben wurde (welche Screens, welche
   übernommenen Elemente).

### `mode=sync`

Wie `mode=spec`, aber ausgelöst durch Drift (Manifest oder Artboard hat sich
geändert, der Block in der Spec ist veraltet — erkennbar am `mockingbirdKind`-
Hinweis des Hooks oder daran, dass `design_hash` im Block nicht mehr zum
aktuellen `mb_design_hash` passt). Zusätzlich zu Schritt 1–5:

6. Wenn sich `screens=` oder `consumes=` im Vergleich zum vorherigen Block
   geändert haben, auch Plan-Header (Kanal A) und die betroffenen
   Task-Design-Tabellen (Kanal C) neu abgleichen — siehe `mode=plan` unten.

### `mode=plan`

Der Plan wird geschrieben oder ergänzt. Dies ist **reine Prosa-Arbeit** — es
gibt kein Skript, das einen Plan-Header oder Task-Design-Tabellen rendert,
weil Tasks und ihre Elementzuordnung projektspezifisch sind und ein Mensch
(über den Plan-Autor) entscheidet, welcher Task welche Screens baut.

1. Design-Block der zugehörigen Spec lesen (er trägt `manifest=`, `system=`,
   `index=`, `screens=`, `design_rev=`).
2. **Kanal A** in den Plan-Header schreiben, direkt nach `**Spec:**` und vor
   `## Global Constraints` — exakter Wortlaut in
   `references/plan-propagation.md#kanal-a`.
3. **Kanal B** in `## Global Constraints` einfügen — die fünf Zeilen aus
   `references/plan-propagation.md#kanal-b`, **wörtlich**, damit der
   SDD-Controller sie unverändert in jeden Dispatch kopieren kann.
4. Für jeden Task mit UI-Anteil: **Kanal C** einfügen — direkt nach
   `**Interfaces:**`, **außerhalb jeder Code-Fence** (eine unbalancierte
   Fence zerreißt den `task-brief`-Schnitt der Folgetasks). Format und ein
   vollständiges Beispiel in `references/plan-propagation.md#kanal-c`.
   Werte immer wörtlich aus dem Manifest übernehmen, nie umformulieren.
5. Für jeden Task **ohne** UI-Anteil: die Zeile
   `**Design:** kein UI-Anteil.` einfügen. Ein fehlender Kanal-C-Eintrag ist
   nicht von einem vergessenen unterscheidbar — dieser Satz macht "kein
   UI-Anteil" zu einer expliziten, prüfbaren Aussage
   (`/design-check` zählt Tasks ohne `**Design:**`).
6. **Kanal D**: einen `DESIGN-COVERAGE`-Block gemäß
   `references/plan-propagation.md#kanal-d` an das Ende des Plans anhängen
   — eine Zeile je Element mit dem Task, der es baut.

### `mode=split`

Ein bestehender Spec wird auf mehrere Teil-Specs aufgeteilt (typischerweise
im Rahmen von `superpowers:writing-plans`, wenn die Dekomposition ansteht).
Vollständiger Ablauf in `references/splitting.md`. Kurzfassung:

1. Zuordnung Screens → Teil-Spec vorschlagen, dem User zeigen, genehmigen
   lassen.
2. `allocations:` im Manifest schreiben (`owns` je Teil-Spec, `revision`
   erhöhen, `changelog`-Eintrag mit `touched`).
3. Für jede Teil-Spec `mode=spec` wie oben ausführen, mit `--screens` auf
   deren `owns`-Liste beschränkt.
4. Ein Element, das von mehreren Teil-Specs benutzt wird (`uses:`), erscheint
   in **genau einer** Spec in der Tabelle (der besitzenden) und in allen
   anderen nur in der Prosaliste „Übernommene Elemente" — niemals in zwei
   Tabellen. Ein Tabellenstatus `reference` existiert bewusst nicht: preflight
   Stage 1 würde eine fremd gebaute Zeile sonst als ungedeckte Anforderung
   melden.

## Advisory, nie blockierend

Wie preflight nudgt der PostToolUse-Hook nur — er kann dieses Skill nicht
erzwingen. Ignoriere den Hinweis, wenn die Abweichung beabsichtigt ist
(z. B. ein Backend-only-Projekt, das der Hook fälschlich für UI-lastig hält).

## Behebbare Grenzen werden behoben, nicht gemeldet

Stößt dieses Skill auf eine Grenze des Plugins, die sich mit vertretbarem
Aufwand beheben lässt — ein Adapter, der einen Dateityp nicht sieht; ein
Parser-Subset, das eine gebräuchliche Schreibweise ablehnt; ein Locator, der
ein übliches Muster nicht kennt — dann wird sie **im Plugin behoben**: Code,
Test, Commit, ein Satz im Bericht. Nicht als „bekannte Lücke" in das Projekt
des Users schreiben, nicht fragen, ob man soll. Rückfrage nur, wenn die
Behebung eine Design-Entscheidung des Users berührt oder das Verhalten für
andere Projekte spürbar ändert. (Regel des Users vom 2026-09-04.)
