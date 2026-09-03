import { db } from "./db";
export const routes = {
  "GET /api/v1/departments": () => db.query("SELECT id, name FROM departments"),
  "GET /api/v1/offices": () => db.query("SELECT id, name FROM locations"), // "office" is the product's word for a location
  "GET /api/v1/cost-centers": () => db.query("SELECT id, name FROM cost_centers"),
  "GET /api/v1/job-titles": () => db.query("SELECT id, name FROM roles"), // "job title" is the product's word for a role
  "POST /api/v1/employees": (body: unknown) => db.exec("INSERT INTO employees ...", body),
};
