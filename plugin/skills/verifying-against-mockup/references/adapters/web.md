# Adapter-Hinweise: Web

Hinweisliste, keine Regeln — hilft beim Suchen, ist keine Checkliste, die
mechanisch abgehakt wird.

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
