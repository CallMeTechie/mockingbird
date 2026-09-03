export function useJobTitles() {
  return fetchJson("/api/v1/job-titles"); // -> roles table, "job title" is the product's own word for role
}
function fetchJson(url: string) { return []; }
