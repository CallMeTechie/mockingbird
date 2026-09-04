# Adapter-Hinweise: Web

Hinweisliste, keine Regeln — hilft beim Suchen, ist keine Checkliste, die
mechanisch abgehakt wird.

## Lauffähigkeit (`mb_adapter_healthcheck`)

Der Adapter benennt die Befehle, die beweisen, dass der Code noch **läuft** —
er führt sie nie selbst aus, damit Zeitlimits und Berechtigungen beim
Aufrufer bleiben. Für Web sind das die in `package.json` real vorhandenen
Skripte `lint`, `typecheck`, `test`, `build`, je Paket eine Zeile
`<verzeichnis><TAB><befehl><TAB>whole|files`; niemals ein Dauerläufer wie
`dev`. Die `source_roots:` des Manifests grenzen im Monorepo auf die Pakete
ein, in denen die Screens wirklich liegen.

`lint` kommt als `files` und nennt das Werkzeug direkt (`npx eslint`), weil
ein npm-Skript `eslint .` sich durch ein angehängtes Pfadargument nicht
eingrenzen lässt — es liefe erst über alles und dann über den Pfad. Ein
unbekannter Linter fällt auf den ganzheitlichen Lauf zurück, statt eine
Eingrenzung zu erfinden, die nicht stimmt.

Im Monorepo entscheidet `source_roots:` nicht allein. `files`-Befehle des
Wurzelpakets kommen **zusätzlich** zu denen der Pakete, nicht an ihrer Stelle:
welche Pfade ein Linter wirklich abdeckt, bestimmt seine Konfiguration, nicht
dieses Skript. Outposts Wurzelkonfiguration trifft nur `server/` und
`scripts/` und meldet eine Client-Datei als „ignored"; die Client-Konfiguration
deckt den Client ab. Nur einen von beiden zu behalten legt stillschweigend das
Linting des halben Repos still. Ein `whole`-Befehl des Wurzelpakets bleibt
dagegen nur für eine Art, die kein eingegrenztes Paket anbietet — typischerweise
die Testsuite, die oben liegt (Outpost: 1086 Tests, für einen Client-Scan
unsichtbar).

## Wo Binding und Datenquelle typischerweise aussehen

- **React**: `useState`/`useEffect` mit einem Fetch, ein Query-Hook
  (`useQuery`, `useSWR`), oder Props von einer Elternkomponente. Die
  Datenquelle ist oft nicht in derselben Datei wie das Rendering — folge
  dem Hook-Namen in seine Definition.
- **Vue**: `computed`, ein `useX()`-Composable, oder Pinia/Vuex-Store-
  Zugriff (`store.state.x`, `mapState`).
- **Svelte**: ein `$store`, eine `load`-Funktion in `+page.js`/`+page.ts`.
- **Plain HTML/Server-gerendert**: Template-Variable, oft aus einem
  Controller/Handler, der die Daten direkt vor dem Rendern lädt.

## Wo der Handler/Endpunkt typischerweise sitzt

Backend-Route-Definition (Express `router.get(...)`, ähnliche Frameworks),
ein Resolver (GraphQL), oder ein Service-Objekt, das der Frontend-Hook
aufruft. Der Name des Frontend-Hooks verrät oft den Endpunkt-Pfad
(`useOrders` → `/api/.../orders`), aber verifiziere das am tatsächlichen
Aufruf, nicht am Namen.

## Wo das Endglied typischerweise sitzt

Eine ORM-Modelldefinition, ein SQL-Query mit `SELECT … FROM …`, ein
GraphQL-Schema-Feld, oder — der häufigste echte Treffer — ein
hartkodiertes Array/Objekt direkt im Frontend-Code (`stub-data`).

## Locator-Konvention dieses Plugins

`data-ui-id="<ID>"` (Tier A) ist die stärkste Evidenz; ebenso die
React-Prop-Schreibweise `dataUiId="<ID>"`, wenn eine gemeinsame Komponente
den Marker durchreicht. Ohne sie degradiert
der Locator sauber auf Tier B (Label-String) oder C (Namenskonvention) —
das ist kein Fehler, nur ein schwächerer Beweis, und das
Coverage-Regelwerk deckelt Tier-C-Befunde bereits automatisch.
