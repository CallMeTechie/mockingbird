export function useAllOrgUnits() {
  return fetchJson("/api/v1/org-units");
}
function fetchJson(url: string) { return []; }
