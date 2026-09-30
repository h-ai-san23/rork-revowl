import type { Env } from "./env";
import { highestPlan, planForProduct, type BillingState, type PlanId } from "./plans";

export type BillingSnapshot = {
  plan: PlanId;
  state: BillingState;
  productId: string | null;
  expiresAt: number | null;
  willRenew: boolean;
  isSandbox: boolean;
  store: string | null;
  trialUsed: boolean;
  billingIssue: boolean;
  managementUrl: string | null;
  verifiedAt: number;
  source: "revenuecat" | "none";
};

type RCEntitlement = { expires_date: string | null; product_identifier: string; grace_period_expires_date?: string | null };
type RCSubscription = {
  expires_date: string | null;
  period_type?: string;
  unsubscribe_detected_at?: string | null;
  billing_issues_detected_at?: string | null;
  grace_period_expires_date?: string | null;
  store?: string;
  is_sandbox?: boolean;
};
type RCSubscriber = {
  subscriber?: {
    entitlements?: Record<string, RCEntitlement>;
    subscriptions?: Record<string, RCSubscription>;
    management_url?: string | null;
  };
};

const ts = (s: string | null | undefined) => (s ? Date.parse(s) : null);

/** Pure: derives the billing snapshot from a RevenueCat subscriber payload. */
export function parseSubscriber(body: RCSubscriber, now = Date.now()): BillingSnapshot {
  const sub = body.subscriber ?? {};
  const ents = sub.entitlements ?? {};
  const subs = sub.subscriptions ?? {};
  const active: string[] = [];
  let inGrace = false;
  for (const [id, e] of Object.entries(ents)) {
    const exp = ts(e.expires_date);
    const grace = ts(e.grace_period_expires_date);
    if (exp === null || exp > now) active.push(id);
    else if (grace !== null && grace > now) {
      active.push(id);
      inGrace = true;
    }
  }
  const trialUsed = Object.values(subs).some((s) => s.period_type === "trial" || s.period_type === "intro");
  const plan = highestPlan(active);
  if (plan === "none") {
    const hadAny = Object.keys(subs).length > 0;
    return {
      plan: "none",
      state: hadAny ? "expired" : "none",
      productId: null,
      expiresAt: null,
      willRenew: false,
      isSandbox: false,
      store: null,
      trialUsed,
      billingIssue: false,
      managementUrl: sub.management_url ?? null,
      verifiedAt: now,
      source: "revenuecat",
    };
  }
  const productId = Object.entries(ents).find(([id]) => id === plan)?.[1].product_identifier ?? null;
  const s = productId ? subs[productId] : undefined;
  const planFromProduct = planForProduct(productId);
  const state: BillingState = inGrace ? "grace" : s?.period_type === "trial" ? "trial" : "active";
  return {
    plan: planFromProduct !== "none" ? planFromProduct : plan,
    state,
    productId,
    expiresAt: ts(s?.expires_date ?? ents[plan]?.expires_date ?? null),
    willRenew: !s?.unsubscribe_detected_at,
    isSandbox: s?.is_sandbox ?? false,
    store: s?.store ?? null,
    trialUsed,
    billingIssue: !!s?.billing_issues_detected_at,
    managementUrl: sub.management_url ?? null,
    verifiedAt: now,
    source: "revenuecat",
  };
}

/**
 * Fetches the RevenueCat subscriber for a property (app_user_id = property id).
 * Prefers the secret key; falls back to the project's public SDK keys (read-only).
 */
export async function fetchSubscriber(env: Env, appUserId: string): Promise<BillingSnapshot | null> {
  const keys = [env.REVENUECAT_SECRET_API_KEY, env.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY, env.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY].filter(
    (k): k is string => typeof k === "string" && k.length > 0,
  );
  let best: BillingSnapshot | null = null;
  for (const key of keys) {
    try {
      const res = await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`, {
        headers: { Authorization: `Bearer ${key}`, "X-Platform": "ios", Accept: "application/json" },
      });
      if (!res.ok) continue;
      const snap = parseSubscriber((await res.json()) as RCSubscriber);
      if (!best || rank(snap) > rank(best)) best = snap;
      if (snap.plan !== "none" && key === env.REVENUECAT_SECRET_API_KEY) break;
    } catch (e) {
      console.warn("revenuecat fetch failed", e instanceof Error ? e.message : String(e));
    }
  }
  return best;
}

function rank(s: BillingSnapshot): number {
  const order: PlanId[] = ["none", "essentials", "insight", "horizon"];
  return order.indexOf(s.plan) * 10 + (s.state === "active" ? 3 : s.state === "trial" ? 2 : s.state === "grace" ? 1 : 0);
}
