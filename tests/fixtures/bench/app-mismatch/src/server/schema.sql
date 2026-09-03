CREATE TABLE groups (id INTEGER PRIMARY KEY, name TEXT NOT NULL);          -- ad-hoc user groups for permissions
CREATE TABLE org_units (id INTEGER PRIMARY KEY, name TEXT NOT NULL, kind TEXT NOT NULL); -- kind: DEPARTMENT | LOCATION | COST_CENTER
CREATE TABLE employees (id INTEGER PRIMARY KEY, full_name TEXT NOT NULL, org_unit_id INTEGER REFERENCES org_units(id));
