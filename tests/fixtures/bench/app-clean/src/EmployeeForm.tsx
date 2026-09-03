import { useDepartments } from "./hooks/useDepartments";
import { useOffices } from "./hooks/useOffices";
import { useCostCenters } from "./hooks/useCostCenters";
import { useJobTitles } from "./hooks/useJobTitles";
import { useBillingProfile } from "./hooks/useBillingProfile";
import { t } from "./i18n";
import { useState } from "react";
import { designTokens } from "./designTokens";
import { saveEmployee } from "./api/employees";
import { navigate } from "./router";

// Correct, but named unlike the manifest's vocabulary ("dept" alias, not
// "department") and sourced through a differently-named hook -- must not be
// flagged just because the identifiers don't match the manifest verbatim.
// Golden: UI-EMP-DEPT | semantic | ok
function DeptField() {
  const dept = useDepartments();
  return (
    <select data-ui-id="UI-EMP-DEPT">
      <option value="">{t("employee.dept.label")}</option>
      {dept.map((d) => (
        <option key={d.id} value={d.id}>{d.name}</option>
      ))}
    </select>
  );
}

// Correct, label pulled from an i18n catalog rather than a literal string --
// the label check must resolve through the catalog, not just grep for the
// literal text "Standort".
// Golden: UI-EMP-LOCATION | semantic | ok
function OfficeField() {
  const offices = useOffices();
  return (
    <select data-ui-id="UI-EMP-LOCATION">
      <option value="">{t("employee.location.label")}</option>
      {offices.map((o) => (
        <option key={o.id} value={o.id}>{o.name}</option>
      ))}
    </select>
  );
}

// Correct. Golden: UI-EMP-COSTCENTER | semantic | ok
function CostCenterField() {
  const centers = useCostCenters();
  return (
    <select data-ui-id="UI-EMP-COSTCENTER">
      <option value="">{t("employee.costcenter.label")}</option>
      {centers.map((c) => (
        <option key={c.id} value={c.id}>{c.name}</option>
      ))}
    </select>
  );
}

// Correct. Golden: UI-EMP-ROLE | semantic | ok
function RoleField() {
  const titles = useJobTitles();
  return (
    <select data-ui-id="UI-EMP-ROLE">
      <option value="">{t("employee.role.label")}</option>
      {titles.map((r) => (
        <option key={r.id} value={r.id}>{r.name}</option>
      ))}
    </select>
  );
}

// Genuine external boundary, same as app-mismatch -- correctly stays
// unverified:external-boundary here too, must not become a false positive
// just because this fixture is "the clean one".
// Golden: UI-EMP-NAME | semantic | unverified:external-boundary
function NameField() {
  const profile = useBillingProfile();
  return <input data-ui-id="UI-EMP-NAME" defaultValue={profile.fullName} />;
}

// Correct handler, correct token usage (imported alias, not the literal
// custom-property name) -- tests that the token check resolves an alias
// instead of demanding the exact --color-accent string.
// Golden: UI-EMP-SAVE | flow | ok, tokens | ok, states | ok
function SaveButton() {
  const accent = designTokens.accent; // resolves to var(--color-accent) via the alias table
  const [error, setError] = useState<string | null>(null);

  async function handleSave() {
    try {
      await saveEmployee();
      navigate("/employees"); // back to the list, as the manifest says
    } catch (e) {
      setError(String(e));
    }
  }

  return (
    <>
      <button data-ui-id="UI-EMP-SAVE" style={{ background: accent }} onClick={handleSave}>
        {t("employee.save.label")}
      </button>
      {error && <p role="alert">{error}</p>}
    </>
  );
}

export function EmployeeForm() {
  return (
    <form>
      <DeptField />
      <OfficeField />
      <RoleField />
      <NameField />
      <SaveButton />
      <CostCenterField />
    </form>
  );
}
