---
description: Measures the verify chain's recall, false-positive rate and hallucination rate against the app-mismatch/app-clean fixtures.
argument-hint: "[--root DIR] "
---

Führe `/design-verify` im Whole-Screen-Modus gegen beide Fixtures aus
`tests/fixtures/bench/` aus (`app-mismatch`, `app-clean`), sammle die
`MB-COVERAGE`- und `MB-SEAM`-Befunde je Fixture als ein JSON-Array in
`/tmp/mockingbird_bench_<fixture>.json`, dann:

```
${CLAUDE_PLUGIN_ROOT}/../tests/bench/score.sh --mode recall  /tmp/mockingbird_bench_app-mismatch.json tests/bench/expected/mismatch.expected.json
${CLAUDE_PLUGIN_ROOT}/../tests/bench/score.sh --mode fp      /tmp/mockingbird_bench_app-clean.json    tests/bench/expected/clean.expected.json
${CLAUDE_PLUGIN_ROOT}/../tests/bench/score.sh --mode honesty /tmp/mockingbird_bench_app-mismatch.json
```

Funktioniert nur im Repo-Checkout, nicht im installierten Plugin-Cache (dort
fehlt `tests/`) — wie footguns `/footgun-bench`.

Ausgabe: feste Tabelle (Recall, Precision, F1, False-Positives,
Halluzinationsrate) plus zwingend die Zeile
`_Hinweis: LLM-Lauf, nicht deterministisch — Werte können über Läufe
schwanken._` Der Exit-Code ist **informativ**, kein Abbruchgrund.

**Projektverzeichnis:** `--root DIR` legt das Projekt fest (das Verzeichnis mit `docs/design/`). Ohne `--root` gilt das aktuelle Arbeitsverzeichnis bzw. dessen Projekt-Root. So lässt sich ein anderes Projekt bearbeiten, ohne die Session dort zu starten.
