/**
 * Plan and entitlement matrix — the single source of truth for limits.
 * The iOS app renders these values from `GET /v1/plans`; it never hardcodes them.
 */
export type PlanId = "none" | "essentials" | "insight" | "horizon";
export type BillingState = "none" | "trial" | "active" | "grace" | "expired";

export type PlanLimits = {
  competitors: number;
  teamMembers: number;
  orevAnswersPerMonth: number;
  orevAnswersPerTrial: number;
  eventHorizonDays: number;
  rateRefreshesPerDay: number;
  rateHorizonDays: number;
  /** Hard ceiling on variable AI/data spend per property per calendar month (USD). */
  monthlyCostCeilingUsd: number;
};

export type Plan = {
  id: PlanId;
  name: string;
  priceUsdMonthly: number;
  productId: string | null;
  entitlement: string | null;
  recommended: boolean;
  tagline: string;
  limits: PlanLimits;
  features: string[];
};

export const TRIAL_DAYS = 7;

export const PLANS: Record<PlanId, Plan> = {
  none: {
    id: "none",
    name: "Setup",
    priceUsdMonthly: 0,
    productId: null,
    entitlement: null,
    recommended: false,
    tagline: "Finish setting up your property.",
    limits: {
      competitors: 1,
      teamMembers: 1,
      orevAnswersPerMonth: 5,
      orevAnswersPerTrial: 5,
      eventHorizonDays: 14,
      rateRefreshesPerDay: 1,
      rateHorizonDays: 7,
      monthlyCostCeilingUsd: 0.5,
    },
    features: ["Property setup", "Data import", "One competitor preview"],
  },
  essentials: {
    id: "essentials",
    name: "Essentials",
    priceUsdMonthly: 29,
    productId: "revowl_essentials_monthly",
    entitlement: "essentials",
    recommended: false,
    tagline: "The daily essentials for an independent property.",
    limits: {
      competitors: 1,
      teamMembers: 1,
      orevAnswersPerMonth: 50,
      orevAnswersPerTrial: 15,
      eventHorizonDays: 30,
      rateRefreshesPerDay: 1,
      rateHorizonDays: 14,
      monthlyCostCeilingUsd: 7,
    },
    features: [
      "Daily briefing from Orev",
      "Occupancy, ADR and RevPAR from your data",
      "1 competitor tracked daily",
      "30-day event calendar",
      "50 Orev answers a month",
    ],
  },
  insight: {
    id: "insight",
    name: "Insight",
    priceUsdMonthly: 99,
    productId: "revowl_insight_monthly",
    entitlement: "insight",
    recommended: true,
    tagline: "A full view of your market, twice a day.",
    limits: {
      competitors: 5,
      teamMembers: 3,
      orevAnswersPerMonth: 250,
      orevAnswersPerTrial: 60,
      eventHorizonDays: 90,
      rateRefreshesPerDay: 2,
      rateHorizonDays: 30,
      monthlyCostCeilingUsd: 20,
    },
    features: [
      "Everything in Essentials",
      "5 competitors, refreshed twice daily",
      "90-day event calendar",
      "Booking pace from your snapshots",
      "250 Orev answers a month",
      "Up to 3 team members",
    ],
  },
  horizon: {
    id: "horizon",
    name: "Horizon",
    priceUsdMonthly: 199,
    productId: "revowl_horizon_monthly",
    entitlement: "horizon",
    recommended: false,
    tagline: "Look further ahead with a larger competitive set.",
    limits: {
      competitors: 9,
      teamMembers: 5,
      orevAnswersPerMonth: 750,
      orevAnswersPerTrial: 175,
      eventHorizonDays: 180,
      rateRefreshesPerDay: 4,
      rateHorizonDays: 60,
      monthlyCostCeilingUsd: 40,
    },
    features: [
      "Everything in Insight",
      "9 competitors, refreshed 4× daily",
      "180-day event calendar",
      "750 Orev answers a month",
      "Up to 5 team members",
    ],
  },
};

export const PAID_PLAN_ORDER: PlanId[] = ["essentials", "insight", "horizon"];

export function planForEntitlement(entitlement: string | null | undefined): PlanId {
  if (entitlement === "horizon" || entitlement === "insight" || entitlement === "essentials") return entitlement;
  return "none";
}

export function planForProduct(productId: string | null | undefined): PlanId {
  if (!productId) return "none";
  for (const id of PAID_PLAN_ORDER) {
    const p = PLANS[id];
    if (p.productId && productId.startsWith(p.productId)) return id;
  }
  return "none";
}

/** Highest plan among a set of active entitlement identifiers. */
export function highestPlan(entitlements: string[]): PlanId {
  let best: PlanId = "none";
  for (const e of entitlements) {
    const p = planForEntitlement(e);
    if (PAID_PLAN_ORDER.indexOf(p) > PAID_PLAN_ORDER.indexOf(best)) best = p;
  }
  return best;
}

/** Orev answer allowance for the current billing state. Trials get a smaller allowance. */
export function orevAllowance(plan: PlanId, state: BillingState): number {
  const limits = PLANS[plan].limits;
  if (plan === "none" || state === "expired" || state === "none") return PLANS.none.limits.orevAnswersPerMonth;
  return state === "trial" ? limits.orevAnswersPerTrial : limits.orevAnswersPerMonth;
}

export function effectivePlan(plan: PlanId, state: BillingState): PlanId {
  if (state === "trial" || state === "active" || state === "grace") return plan;
  return "none";
}

export function publicPlans(): Plan[] {
  return PAID_PLAN_ORDER.map((id) => PLANS[id]);
}
