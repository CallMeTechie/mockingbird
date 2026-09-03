export function useCostCenters() {
  return fetchJson("/api/v1/cost-centers"); // -> cost_centers table
}
function fetchJson(url: string) { return []; }
