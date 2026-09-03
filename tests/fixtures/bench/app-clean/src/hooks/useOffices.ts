export function useOffices() {
  return fetchJson("/api/v1/offices"); // -> locations table, offices is the product's own word for it
}
function fetchJson(url: string) { return []; }
