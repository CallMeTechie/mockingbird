const catalog: Record<string, string> = {
  "employee.dept.label": "Abteilung",
  "employee.location.label": "Standort",
  "employee.costcenter.label": "Kostenstelle",
  "employee.role.label": "Rolle",
  "employee.save.label": "Speichern",
};
export function t(key: string) { return catalog[key] ?? key; }
