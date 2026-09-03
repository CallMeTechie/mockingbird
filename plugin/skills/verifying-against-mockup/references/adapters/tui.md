# Adapter-Hinweise: Tui (nur dokumentiert)

Kein v0.1-Adapter. `plugin/scripts/adapters/tui.sh` meldet alle
Capabilities als `no` — ein Dispatch auf diesem Adapter wird nie
ausgeführt, weil `--coverage` jedes Element automatisch als
`unverified:out-of-scope` klassifiziert und das Verdikt entsprechend auf
MISMATCH mit dem Grund „Adapter nicht implementiert" setzt (siehe
`plugin/scripts/mockingbird-scope.sh`, der Kommentar zum Adapter-Vertrag).

Diese Datei ist ein Platzhalter für den Tag, an dem jemand diesen Adapter
tatsächlich implementiert — dann gehört hierhin dieselbe Art von
Hinweisliste wie in `web.md`: wo Binding und Datenquelle auf dieser
Plattform typischerweise aussehen, wo der Handler sitzt, wo das Endglied
sitzt.
