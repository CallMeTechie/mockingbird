export function useGroups() {
  return fetchJson("/api/v1/groups");
}
function fetchJson(url: string) { return []; }
