import { billingClient } from "@acme/billing-sdk";
export function useBillingProfile() {
  return billingClient.getCurrentEmployeeProfile();
}
