import { useGroups } from "./hooks/useGroups";
import { useAllOrgUnits } from "./hooks/useOrgUnits";
import { useBillingProfile } from "./hooks/useBillingProfile";

// DEVIATION (semantic/violated): label says "Abteilung" (department), but
// the data actually comes from groups — the exact bug this plugin exists to
// catch. Golden: UI-EMP-DEPT | semantic | violated
function DepartmentField() {
  const groups = useGroups();
  return (
    <select data-ui-id="UI-EMP-DEPT">
      <option value="">Abteilung</option>
      {groups.map((g) => (
        <option key={g.id} value={g.id}>{g.name}</option>
      ))}
    </select>
  );
}

// DEVIATION (semantic/partial): label says "Standort" (location), source
// delivers ALL org units, not narrowed to locations. Right concept, missing
// narrowing -- the subtle variant.
// Golden: UI-EMP-LOCATION | semantic | partial
function LocationField() {
  const orgUnits = useAllOrgUnits();
  return (
    <select data-ui-id="UI-EMP-LOCATION">
      <option value="">Standort</option>
      {orgUnits.map((u) => (
        <option key={u.id} value={u.id}>{u.name}</option>
      ))}
    </select>
  );
}

// DECOY 1: looks like the same "unfiltered org units" shape as LocationField,
// but IS correctly narrowed via .filter() -- this must be judged "ok", not
// flagged as a violation just because it resembles the department bug.
// Golden: UI-EMP-COSTCENTER | semantic | ok
function CostCenterField() {
  const orgUnits = useAllOrgUnits();
  const costCenters = orgUnits.filter((u) => u.kind === "COST_CENTER");
  return (
    <select data-ui-id="UI-EMP-COSTCENTER">
      <option value="">Kostenstelle</option>
      {costCenters.map((c) => (
        <option key={c.id} value={c.id}>{c.name}</option>
      ))}
    </select>
  );
}

// DEVIATION (stub-data / semantic/violated): a hardcoded literal array
// instead of any real data source. The most common real-world finding.
// Golden: UI-EMP-ROLE | semantic | violated
function RoleField() {
  const roles = ["Admin", "Editor", "Viewer"];
  return (
    <select data-ui-id="UI-EMP-ROLE">
      <option value="">Rolle</option>
      {roles.map((r) => (
        <option key={r} value={r}>{r}</option>
      ))}
    </select>
  );
}

// DECOY 2: a genuine external boundary. useBillingProfile calls a service
// that is not in this repo -- there is no terminal file:line to find here,
// on either side. Must be judged unverified:external-boundary, never
// violated (violated requires an existing terminal link).
// Golden: UI-EMP-NAME | semantic | unverified:external-boundary
function NameField() {
  const profile = useBillingProfile();
  return <input data-ui-id="UI-EMP-NAME" defaultValue={profile.fullName} />;
}

// DEVIATION (flow/violated): the button exists, but has no handler at all --
// the most common flow-stage finding.
// Golden: UI-EMP-SAVE | flow | violated
function SaveButton() {
  // hardcoded raw color instead of the design token --color-accent
  // DEVIATION (tokens/violated). Golden: file-level, tokens stage.
  return <button data-ui-id="UI-EMP-SAVE" style={{ background: "#ff00aa" }}>Speichern</button>;
}

// DEVIATION (states/partial): the manifest declares a "default" and an
// "error" state for UI-EMP-SAVE; only "default" (no error branch, no catch,
// no error UI at all) exists here.
export function EmployeeForm() {
  return (
    <form>
      <DepartmentField />
      <LocationField />
      <CostCenterField />
      <RoleField />
      <NameField />
      <SaveButton />
    </form>
  );
}
