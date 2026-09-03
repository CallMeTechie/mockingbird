// Tier-C-friendly on purpose: no data-ui-id marker lives here, the naming
// convention is the only thread ("Dept" segment) -- proves the plausibility
// check still resolves a correct binding through a weaker locator tier.
export function useDepartments() {
  return fetchJson("/api/v1/departments"); // -> departments table
}
function fetchJson(url: string) { return []; }
