import { db } from "./db";
export const routes = {
  "GET /api/v1/groups": () => db.query("SELECT id, name FROM groups"),
  "GET /api/v1/org-units": () => db.query("SELECT id, name, kind FROM org_units"),
};
