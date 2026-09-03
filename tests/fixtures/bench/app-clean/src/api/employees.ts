export async function saveEmployee() {
  return fetch("/api/v1/employees", { method: "POST" });
}
