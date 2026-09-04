---
name: verifying-against-mockup
description: Use to check whether built code actually matches docs/design/manifest.yaml — not just that elements exist, but that a control labelled "Abteilung" is really wired to departments and not to groups. Runs a 6-stage review chain (structure/semantic/states/tokens/flow, then consolidation), applies provably correct fixes with a snapshot+diff, and gives a MATCH/MISMATCH verdict. Invoked by /design-verify, or automatically after a task/plan finishes or before a commit.
---

# Gebautes gegen das Mockup prüfen

## Overview

Fünf parallele Reviewer-Stufen + ein deterministisches Gate davor +
Konsolidierung im Main-Loop danach — preflight-Bauart: **ein** generischer
`mockingbird:reviewer` mit N Referenz-Mandaten, nicht footguns N
spezialisierte Agent-Dateien. Grund: Medienneutralität. Bei N Stages × M
Adaptern wären footgun-Stil N×M Agent-Dateien; hier ist ein neuer Adapter
eine Referenz plus ein Shell-Fragment.

**Kern des Plugins:** die `semantic`-Stufe prüft nicht „sieht es gleich
aus", sondern „ist die gebaute Funktion plausibel zu dem, was das Mockup
verspricht". Details: `references/stages/semantic.md`.

**Input:** `mode` (`verify` | `fix`) + `path` zum Projekt-Root (aus `--root DIR` des Commands, sonst das aktuelle Projekt). Quelle:
`/design-verify`-Command, ein Hook-Hinweis, oder ein automatischer Trigger
nach Task-/Plan-Abschluss bzw. vor einem Commit.

## Schritt 1 — Lock

`<project>/.claude/.mockingbird-running` setzen (Unix-Timestamp + Session-ID,
wie in `plugin/hooks/mockingbird-hooklib.sh`, `mb_write_lock`). Ist bereits
ein frischer, fremder Lock gesetzt: abbrechen, nichts tun.

## Schritt 2 — Deterministisches Gate

```
${CLAUDE_PLUGIN_ROOT}/scripts/mockingbird-scope.sh --validate --root <projekt>
```

Exit ≠ 0: abbrechen, Fehler melden — kein Sinn, gegen ein ungültiges
Manifest zu prüfen. Danach `--scope` (ggf. `--since <ref>`), um die
betroffenen Screens zu bestimmen, und je betroffenem Screen `--elements`,
um den Coverage-Nenner zu bilden.

Ist der aufgelöste Adapter nicht `web` (bislang der einzige vollständig
implementierte, siehe `references/adapters/`): sofort mit `MISMATCH` und
der Begründung „Adapter `<name>` nicht implementiert — es wurde nichts
geprüft" abbrechen. **Nie** ein stilles `MATCH` für einen Adapter
ausgeben, der nichts prüfen kann.

## Schritt 3 — Fan-out (fünf parallele Dispatches)

**In einer einzigen Nachricht** fünf `mockingbird:reviewer`-Dispatches, damit
sie parallel laufen — genau wie footguns Fünffach-Dispatch. Jeder bekommt
**exakt ein** Stage-Mandat, zitiert aus `references/stages/<stage>.md` (nie
die ganze Datei an alle, nie mehrere Stages an einen Dispatch), plus den
Element-Ausschnitt aus `--elements` für die betroffenen Screens und den
relevanten Abschnitt aus `references/adapters/<adapter>.md`.

Bei vielen Elementen: nach Screens shardieren (mehrere Dispatches derselben
Stage, je eine Scheibe) statt einen einzelnen überladenen Dispatch zu
bauen — genau der Grund, warum preflight-Stil hier gewählt wurde.

## Schritt 4 — Deterministische Nachbereitung je Dispatch

Aus jeder Dispatch-Antwort **nur den Block** zwischen `MB-SEAM`/`MB-COVERAGE`
und `END` übernehmen — Reviewer setzen gelegentlich einen Satz Prosa davor
(im ersten Live-Lauf beobachtet). Dann für jeden `semantic`- und
`flow`-Dispatch, **bevor** seine Befunde in die Konsolidierung einfließen:

```
${CLAUDE_PLUGIN_ROOT}/scripts/mockingbird-scope.sh --check-seam <dispatch-output> --root <projekt>
```

Das wendet die vier Anti-Halluzinations-Regeln an (siehe
`plugin/lib/mockingbird-coveragelib.sh`, `mb_check_seam`) — **in Bash, nicht
im Prompt**. Ein `violated` ohne belegtes `terminal`, ein Link auf eine
nicht existierende Datei, ein `unverified:*` ohne jeden Beleg, ein
Tier-C-`violated`: alle werden hier automatisch herabgestuft, bevor ein
Mensch oder der Konsolidator sie sieht.

## Schritt 5 — Konsolidierung (Main-Loop, nicht delegiert)

Alle Dispatch-Ausgaben (nach `--check-seam`) zu einer `MB-COVERAGE`-Datei
zusammenführen und auswerten:

```
${CLAUDE_PLUGIN_ROOT}/scripts/mockingbird-scope.sh --coverage <merged-file> --root <projekt>
```

Exit 0 = `MATCH`/`MATCH WITH NOTES`, Exit 1 = `MISMATCH`. **Das Verdikt
kommt ausschließlich aus diesem Aufruf** — es wird nie von einem LLM neu
formuliert oder abgewogen (Regelwerk: `references/coverage-rules.md`).
Diese Befunde werden **nicht** adversarial gegengeprüft (Regel 9) — der
Streit gehört in eine bessere Stage-Prüfung, nicht in eine zusätzliche
Bewertungsrunde.

Bericht zusammenstellen: Blocker, Important, offene Lücken — direkt aus der
`--coverage`-Ausgabe, nicht neu erfunden.

## Schritt 6 — Fixes (nur `mode=fix`, oder nach Rückfrage bei `mode=verify`)

1. Snapshot **vor jedem Schreiben** (git-Commit
   `mockingbird: snapshot <basename> before fix`, oder `.bak`-Datei bei
   fremden gestagten Änderungen — Mechanik identisch zu preflight).
2. Aus den Befunden die fixbaren Fälle nach `references/fix-policy.md`
   auswählen — **nur** die vier dort definierten Klassen, nie mehr.
3. `mockingbird:editor` dispatchen, mit der fertigen Fix-Liste und dem
   Ergebnis von `mockingbird-scope.sh --fix-scope --root <projekt>` als
   Allowlist.
4. **Diff gegen den Snapshot zeigen**, nicht nur eine Fix-Liste.
5. Re-Verify: für die drei rein deterministischen Klassen genügt ein
   erneuter `--tokens`/`--locate`-Lauf (LLM-frei). Für `semantic`/`flow`-
   Fixes ein gezielter Reviewer-Dispatch nur auf den betroffenen Elementen.
   **Hartes Cap: eine Runde.**

## Schritt 7 — State und Freigabe

`<project>/.claude/.mockingbird-verified` schreiben
(`<manifest-sha256>\t<screen-id>\t<verdict>`, atomar ersetzend wie
preflights `.preflight-reviewed`). Lock lösen. Bericht ausgeben.

## Advisory, nie destruktiv ohne Zustimmung

`mode=verify` schreibt nie Code — nur der Bericht. `mode=fix` schreibt nur
nach den Regeln aus `fix-policy.md`, immer mit vorherigem Snapshot und
sichtbarem Diff. Bei Unsicherheit, ob ein Fix wirklich sicher ist: nicht
anwenden, nur melden — der Editor-Agent hat dafür keinen Ermessensspielraum.

## Behebbare Grenzen werden behoben, nicht gemeldet

Stößt dieses Skill — typischerweise über einen Adapter — auf eine Grenze des Plugins, die sich mit vertretbarem
Aufwand beheben lässt — ein Adapter, der einen Dateityp nicht sieht; ein
Parser-Subset, das eine gebräuchliche Schreibweise ablehnt; ein Locator, der
ein übliches Muster nicht kennt — dann wird sie **im Plugin behoben**: Code,
Test, Commit, ein Satz im Bericht. Nicht als „bekannte Lücke" in das Projekt
des Users schreiben, nicht fragen, ob man soll. Rückfrage nur, wenn die
Behebung eine Design-Entscheidung des Users berührt oder das Verhalten für
andere Projekte spürbar ändert. (Regel des Users vom 2026-09-04.)
