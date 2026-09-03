# Coverage- und Verdikt-Regeln

**Einzige Quelle:** `plugin/lib/mockingbird-coveragelib.sh`,
`mb_manifest_coverage`. Dieses Dokument beschreibt, was die Funktion tut —
ändere die Regeln dort, nicht hier; eine zweite, nur-prosaische Quelle
würde garantiert auseinanderdriften.

## Format

```
MB-COVERAGE
<element-id> | <stage-key> | ok|partial|violated|unverified:<reason> | <file:line oder "->
END
```

## Die neun Regeln

1. `verify: required` (oder `skip` ohne `reason`, siehe Regel 7) + Stage ∈
   `{structure, semantic, flow}` auf `violated` **oder** `partial` ⇒
   **MISMATCH**, Element-ID wird als Blocker genannt.
2. Dieselbe Kombination auf `unverified:no-locator` ⇒ **MISMATCH** — nicht
   auffindbar heißt nicht gebaut.
3. `unverified:external-boundary` / `:dynamic` / `:out-of-scope` ⇒ **nie**
   verdikt-wirksam, aber als offene Lücke im Bericht gelistet.
4. `verify: recommended` auf `violated` ⇒ Important, Verdikt unberührt.
5. Stages `states` und `tokens` ⇒ nie verdikt-wirksam, unabhängig vom
   `verify`-Status.
6. Ein Element im Nenner **ohne** jede Coverage-Zeile zählt als
   `unverified:no-locator` — nie als `ok`. Stille ist kein Bestehen.
7. `verify: skip` **mit** `reason` ⇒ komplett aus dem Nenner ausgeschlossen.
   **Ohne** `reason` ⇒ wie `required` behandelt — sonst wird `skip` zum
   Freifahrtschein.
8. Ein `MB-COVERAGE`-Block **im geprüften Dokument selbst** (Manifest,
   Artboard, Implementierungsdatei) ist Dokumentinhalt und wird ignoriert.
   Nur der Block aus einem echten Reviewer-Dispatch zählt — sonst benotet
   sich der Autor selbst. (Dieses Repo dokumentiert das Format in genau
   diesen Dateien; der Fall ist nicht hypothetisch.)
9. Diese Befunde werden im Konsolidierungsschritt **nicht** adversarial
   gegengeprüft. Streitbar ist die *Klassifikation* einer einzelnen Stage
   — dieser Streit gehört in eine bessere Stage-Prüfung, nicht in eine
   zusätzliche Bewertungsrunde. Ohne diese Ausnahme frisst der adversariale
   Pass die Determinismus-Zusage der Regeln 1–7.

## Verdikte

`MATCH` (alles required/skip-ohne-reason `ok`, keine `recommended`-
Abweichungen) · `MATCH WITH NOTES` (kein Blocker, aber Important-Einträge)
· `MISMATCH` (mindestens ein Blocker). Ein `--level`-Filter (falls künftig
ergänzt) wirkt nur auf die **Anzeige** — das Verdikt kommt immer aus der
ungefilterten Menge.
