import {
  EligibilityStatus,
  RegistrationStatus,
  WaiverStatus,
  type Division,
  type Payment,
  type RegistrationRosterEntry
} from "@prisma/client";
import { dictionaries, type Locale } from "@/lib/i18n";

export const TEAM_PRICE_CENTS = 38000;
export const PAYMENT_FEE_CENTS = 1200;

export type RosterInput = {
  firstName: string;
  lastName: string;
  dob: string;
  guardianName?: string;
  guardianEmail?: string;
  waiverAccepted?: boolean;
};

export function calculateEligibility(dob: Date, division: Pick<Division, "minBirthDate" | "maxBirthDate">) {
  if (division.minBirthDate && dob < division.minBirthDate) {
    return EligibilityStatus.INELIGIBLE;
  }

  if (division.maxBirthDate && dob > division.maxBirthDate) {
    return EligibilityStatus.INELIGIBLE;
  }

  return EligibilityStatus.ELIGIBLE;
}

export function getRegistrationStatus(input: {
  roster: Pick<RegistrationRosterEntry, "waiverStatus" | "eligibilityStatus">[];
  division: Pick<Division, "minRoster" | "maxRoster">;
  hasSuccessfulPayment: boolean;
}) {
  const rosterCount = input.roster.length;
  const rosterSizeOk = rosterCount >= input.division.minRoster && rosterCount <= input.division.maxRoster;
  const allWaiversSigned = input.roster.every((entry) => entry.waiverStatus === WaiverStatus.SIGNED);
  const allEligible = input.roster.every(
    (entry) =>
      entry.eligibilityStatus === EligibilityStatus.ELIGIBLE ||
      entry.eligibilityStatus === EligibilityStatus.OVERRIDDEN
  );

  if (!rosterSizeOk || !allEligible) {
    return RegistrationStatus.ELIGIBILITY_REVIEW;
  }

  if (!allWaiversSigned) {
    return RegistrationStatus.WAIVER_INCOMPLETE;
  }

  if (!input.hasSuccessfulPayment) {
    return RegistrationStatus.PENDING_PAYMENT;
  }

  return RegistrationStatus.READY;
}

export function summarizePayment(payments: Pick<Payment, "status">[], locale: Locale = "en") {
  const labels = dictionaries[locale].paymentLabels;

  if (payments.some((payment) => payment.status === "SUCCEEDED" || payment.status === "COMPED")) {
    return labels.paid;
  }

  if (payments.some((payment) => payment.status === "REFUNDED")) {
    return labels.refunded;
  }

  if (payments.some((payment) => payment.status === "FAILED")) {
    return labels.failed;
  }

  return payments.length > 0 ? labels.pending : labels.notStarted;
}

export function summarizeReadiness(input: {
  roster: Pick<RegistrationRosterEntry, "waiverStatus" | "eligibilityStatus">[];
  division: Pick<Division, "minRoster" | "maxRoster">;
  payments: Pick<Payment, "status">[];
  locale?: Locale;
}) {
  const rosterCount = input.roster.length;
  const signedWaivers = input.roster.filter((entry) => entry.waiverStatus === WaiverStatus.SIGNED).length;
  const eligibleCount = input.roster.filter(
    (entry) =>
      entry.eligibilityStatus === EligibilityStatus.ELIGIBLE ||
      entry.eligibilityStatus === EligibilityStatus.OVERRIDDEN
  ).length;
  const payment = summarizePayment(input.payments, input.locale);
  const ready =
    rosterCount >= input.division.minRoster &&
    rosterCount <= input.division.maxRoster &&
    signedWaivers === rosterCount &&
    eligibleCount === rosterCount &&
    payment === dictionaries[input.locale ?? "en"].paymentLabels.paid;

  return {
    roster: `${rosterCount}/${input.division.maxRoster}`,
    waivers: `${signedWaivers}/${rosterCount}`,
    eligibility: `${eligibleCount}/${rosterCount}`,
    payment,
    ready
  };
}
