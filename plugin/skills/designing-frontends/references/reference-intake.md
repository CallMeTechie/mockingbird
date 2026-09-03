# Referenzen einholen (Phase 1)

Je eine Frage pro Nachricht, bevorzugt mit Mehrfachauswahl. Reihenfolge:

1. **„Gibt es ein Produkt, dessen Oberfläche du magst? Nenne 1–3 — Name
   genügt, URL ist besser."**
2. **Das Repo selbst absuchen und den Fund zeigen, statt zu fragen.** Nach
   `tailwind.config.*`, `theme.*`, CSS-Custom-Properties (`:root{--`),
   Markendateien (`*.svg`/`*.png` in `assets|public|static|brand`), einem
   bereits vorhandenen Frontend suchen. Fund → „Ich habe X gefunden. Soll
   das die Basis sein?" Kein Fund → weiter zu Frage 3.
3. **„Gibt es Screenshots, Skizzen, ein Brandbook, eine Farbpalette, ein
   Logo?"**
4. **„Was soll es ausdrücklich *nicht* sein?"** — das stärkste einzelne
   Signal in diesem ganzen Dialog, und die direkte Entsprechung zum
   `not:`-Feld im semantischen Anker jedes Manifest-Elements. Eine Antwort
   wie „nicht wie ein Konzern-Intranet" oder „nicht so verspielt wie X"
   schränkt den Raum stärker ein als jede positive Beschreibung.
5. **„Wer benutzt es, wie oft, unter welchen Bedingungen?"** — Dichte
   (Power-User vs. Gelegenheitsnutzer), Dark Mode, mobil, Tastatur.

## Fallback: drei Archetypen

Kommt bis hierhin nichts Konkretes, nie bei Null anfangen. Drei benannte
Optionen anbieten, mit genau einem Satz Charakterisierung je Option:

| Archetyp | Charakter |
|---|---|
| **Werkzeugartig** | Dicht, tabellenlastig, tastaturgetrieben, kaum Dekor. Näher am Cockpit als an einer Consumer-App. |
| **Großzügig** | Viel Weißraum, starke Typografie, wenige Elemente pro Screen. |
| **Dokumentartig** | Lesbarkeitsgetrieben, eine Spalte, ruhige Farben, Fließtext im Zentrum. |

Höchstens sechs Fragen insgesamt (Fragen 1–5 plus höchstens eine
Rückfrage), bevor in Phase 2 etwas Sichtbares — und sei es nur eine Liste —
entsteht. Der Dialog soll ein Gespräch bleiben, kein Fragebogen.
