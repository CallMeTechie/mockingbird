# Manuelle Integrationsszenarien

Was LLM-getrieben ist und deshalb nicht automatisiert werden kann — genau
der Grund, den preflight für seine eigene `MANUAL-INTEGRATION.md` nennt:
„Skill behavior is LLM-driven and cannot be automated; this is the honest
test boundary." Alles hier ist von Hand gegen eine echte Claude-Code-Session
zu prüfen, nicht per `bash tests/run-all.sh`.

Für Szenarien, die ein Zielprojekt brauchen: ein leeres Verzeichnis mit
`git init` genügt; `docs/superpowers/` und `docs/design/` legt mockingbird
selbst an.

---

## 1. Grüne Wiese

*Stand 2026-09-04: einmal live gefahren (Outpost, per Hand nach SKILL.md) —
Ergebnis und drei Rückmeldungen in `tests/bench/RESULTS.md`.*

`/design` in einem leeren Repo aufrufen.

**Erwartet:**
- Referenzfragen kommen einzeln, nicht als Fragebogen (`references/reference-intake.md`).
- Kommen keine Vorbilder: die drei Archetypen (werkzeugartig/großzügig/dokumentartig) werden angeboten.
- Höchstens sechs Fragen, bevor Phase 2 (Inventar) etwas Sichtbares zeigt.
- **Vor dem Approval-Gate (Phase 6) ist keine Datei geschrieben** — `docs/design/` existiert erst nach der Zustimmung.
- Die Token-Tabelle wird vor dem Schreiben gezeigt.
- IDs folgen der Grammatik `^UI-[A-Z0-9]+(-[A-Z0-9]+){0,3}$` und sind sprechend (`UI-ORDERS-TABLE`, nicht `UI-A1`).
- `docs/design/mockups/tokens.css` existiert und wird von jedem Artboard verlinkt.

## 2. Einfügen neben preflight

Eine Spec mit vorhandenem `<!-- preflight:security:begin -->`-Block anlegen (z. B. per preflight-Security-Profiler), dann `/design-spec` aufrufen.

**Erwartet:**
- Der `mockingbird:design`-Block landet **oberhalb** des Security-Blocks.
- Der Security-Block ist danach byte-identisch (`diff` als Nachweis führen).

## 3. Koexistenz mit preflight im selben Turn

Eine Spec schreiben, die sowohl den mockingbird- als auch den preflight-Hook triggert (z. B. eine neue `docs/superpowers/specs/*-design.md` mit UI-Inhalt, bei existierendem Manifest).

**Erwartet:**
- Beide Hinweise erscheinen im selben Turn, ohne dass einer den anderen unterdrückt (außer der dokumentierte Fall: läuft preflight gerade, schweigt mockingbird für diesen einen Write).
- Nach dem Sync: ein zweiter `/design-sync`-Lauf schreibt nichts (`mb_insert_block` liefert Exit 4).
- Keine Endlosschleife über mehrere Turns.

## 4. Weitergabe Ende-zu-Ende

Eine Spec mit Manifest, dann einen Plan mit `/design-sync` (`mode=plan`) anreichern, dann `superpowers:subagent-driven-development` (oder direkt `scripts/task-brief`) auf einen UI-tragenden Task anwenden.

**Erwartet:**
- Der Task-Brief enthält die Design-Tabelle (Kanal C) wörtlich.
- Er enthält **nicht** den Plan-Header, nicht `**Spec:**`, nicht `## Global Constraints`.
- Ein Implementer, der **nur** mit diesem Brief dispatcht wird, baut ein Element mit `data-ui-id="<ID>"`.

(Die mechanische Hälfte davon ist bereits automatisiert bewiesen:
`tests/run-plan-propagation-tests.sh` läuft das echte, vendorte
superpowers-6.3.0-`task-brief`-awk gegen eine Fixture. Dieses Szenario prüft
die **Autoren-Disziplin** — schreibt die Skill-Anleitung wirklich das, was
sie soll — nicht mehr den Mechanismus selbst.)

## 5. Split

Ein Manifest mit einem `UI-SHELL`-Screen (z. B. Navigation) und zwei
Content-Screens anlegen, `/design-split` mit zwei Teil-Specs aufrufen, eine
davon besitzt `UI-SHELL`, die andere konsumiert es.

**Erwartet:**
- Beide Design-Blöcke tragen `manifest=`, `system=`, `index=`.
- Die Navigation steht in der besitzenden Spec in der **Tabelle**, in der
  konsumierenden nur in der **Prosaliste** „Übernommene Elemente".
- Ein preflight-Plan-Review der konsumierenden Spec meldet die Navigation
  **nicht** als uncovered (Stage 1 sieht sie nicht als eigene Anforderung
  dieser Spec, weil sie nicht in deren Tabelle steht).

## 6. Drift

Ein synchronisiertes Manifest und eine synchronisierte Spec haben, dann ein
Artboard ändern (nicht das Manifest selbst).

**Erwartet:**
- Der Hook nennt beim nächsten Write genau die betroffene Spec, nicht
  alle Specs im Projekt.
- Eine Spec, deren Screens vom geänderten Artboard nicht betroffen sind,
  wird nicht neu geschrieben.

## 7. Erweitern

`/design --extend` auf ein bestehendes Manifest anwenden, einen neuen Screen
hinzufügen.

**Erwartet:**
- Der neue Screen bekommt eine neue ID.
- Bestehende IDs bleiben unverändert, auch wenn sich Labels oder
  Beschreibungen ändern.
- `revision` erhöht sich, `changelog` bekommt einen neuen Eintrag.

## 8. Nicht-UI-Projekt

Eine rein Backend-lastige Spec schreiben (keine Screens, keine UI-Vokabeln),
ohne dass ein Manifest existiert.

**Erwartet:**
- Höchstens ein sanfter, einmaliger Hinweis auf `/design` (gedebounct über
  den Dokument-Hash) — kein wiederholter Druck bei jedem weiteren Write.
- Nach `.claude/.mockingbird-off`: komplettes Schweigen.

## 9. Der Kernfall — semantische Plausibilität

*Stand 2026-09-03: einmal live gefahren (mit Ersatz-Reviewern statt
`mockingbird:reviewer`), Ergebnis in `tests/bench/RESULTS.md`: Recall 1.0,
0 False Positives, 0 Halluzinationen. Mit dem echten Agenten noch offen.*

`/design-verify` gegen `tests/fixtures/bench/app-mismatch/` laufen lassen
(Manifest + Code liegen bereit, siehe `tests/fixtures/bench/`).

**Erwartet, geprüft gegen `tests/bench/expected/mismatch.expected.json`:**
- `UI-EMP-DEPT` (an `useGroups()` gebunden, Label „Abteilung") wird als
  `semantic | violated` gemeldet, **mit** `terminal=<file:line>` in
  `src/hooks/useGroups.ts`.
- `UI-EMP-LOCATION` (an eine ungefilterte Obermenge gebunden) wird als
  `semantic | partial` gemeldet — nicht als `violated`, die subtile
  Variante.
- `UI-EMP-COSTCENTER` (Köder 1: korrekt gefiltert, `.filter(u => u.kind
  === 'COST_CENTER')`) wird **nicht** geflaggt — `semantic | ok`.
- `UI-EMP-NAME` (Köder 2: echte Repo-Grenze zu `@acme/billing-sdk`) wird
  als `unverified:external-boundary` gemeldet, **nicht** als `violated`.
- `UI-EMP-ROLE` (Literal-Array) wird als `semantic | violated` gemeldet.
- `UI-EMP-SAVE` ohne Handler wird als `flow | violated` gemeldet.
- Gesamtverdikt: `MISMATCH`.

Denselben Lauf gegen `tests/fixtures/bench/app-clean/` wiederholen.

**Erwartet:**
- Kein einziger `violated`- oder `partial`-Befund, trotz fremder
  Variablennamen, i18n-Katalog statt Literal-String, Token-Alias statt
  wörtlichem `--color-accent`, und eines Tier-C-Locators bei
  `UI-EMP-DEPT` (kein `data-ui-id`, nur Namenskonvention).
- Gesamtverdikt: `MATCH`.

Für die deterministisch messbare Version dieses Szenarios:
`/mockingbird-bench` (nutzt `tests/bench/score.sh --mode recall|fp|honesty`
gegen dieselben Fixtures). Der Bench-Lauf selbst ist LLM-basiert und daher
nicht deterministisch — nur der Scorer ist es, und der ist bereits durch
`tests/run-bench-tests.sh` automatisiert abgedeckt.

## 10. Fix-Anwendung

Auf der `app-mismatch`-Fixture `/design-verify --fix` laufen lassen (auf
einer Kopie, nicht dem Original unter `tests/fixtures/`).

**Erwartet:**
- Der rohe Hex-Wert (`#ff00aa`) wird automatisch durch das passende Token
  ersetzt (`tokens`-Klasse, Regel aus `fix-policy.md`).
- Label-Drift wird automatisch gefixt, sofern vorhanden.
- Der `UI-EMP-DEPT`/`useGroups()`-Fehler wird **nicht** automatisch
  gefixt, sondern nur gemeldet — außer der Reviewer kann die korrekte
  Alternativquelle ebenfalls mit `file:line` belegen (Evidenz-Tor in
  `fix-policy.md`).
- Vor jedem Schreiben existiert ein Snapshot; am Ende wird ein Diff gegen
  den Snapshot gezeigt, keine reine Fix-Liste.
- `docs/design/manifest.yaml` bleibt unangetastet.
- Re-Verify läuft höchstens eine Runde.
