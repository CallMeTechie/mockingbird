// Calls an external billing microservice not present in this repository.
// There is deliberately no local terminal (table/type/endpoint handler) to
// find -- the point of this fixture is the boundary itself.
import { billingClient } from "@acme/billing-sdk";
export function useBillingProfile() {
  return billingClient.getCurrentEmployeeProfile();
}
