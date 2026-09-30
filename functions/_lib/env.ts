export type DOBinding = Fetcher & {
  setAlarm(className: string, id: string, scheduledTime: number | Date): Promise<void>;
  getAlarm(className: string, id: string): Promise<number | null>;
  deleteAlarm(className: string, id: string): Promise<void>;
};

/** Worker + Durable Object environment. Values come from the project env store. */
export type Env = {
  DO: DOBinding;
  EXPO_PUBLIC_TOOLKIT_URL?: string;
  EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY?: string;
  EXPO_PUBLIC_REVENUECAT_IOS_API_KEY?: string;
  EXPO_PUBLIC_REVENUECAT_TEST_API_KEY?: string;
  /** Set to "true" to disable device-bound sign-in (dev/simulator fallback). */
  DISABLE_DEVICE_AUTH?: string;
  /** RevenueCat secret (sk_...) API key — enables server-verified entitlements. */
  REVENUECAT_SECRET_API_KEY?: string;
  /** Shared secret RevenueCat sends in the Authorization header of webhooks. */
  REVENUECAT_WEBHOOK_AUTH?: string;
  /** Comma-separated list of accepted Sign in with Apple audiences (bundle ids). */
  APPLE_AUDIENCES?: string;
};

export const DEFAULT_APPLE_AUDIENCES = ["app.rork.revowl-ai-hotel-revenue"];

/** Toolkit base URL. The public URL env isn't always spread into the Worker, so default it. */
export function toolkitBase(env: Env): string {
  return (env.EXPO_PUBLIC_TOOLKIT_URL || "https://toolkit.rork.com").replace(/\/$/, "");
}

type DOCall = { method?: string; body?: unknown; headers?: Record<string, string> };

/** Dispatches an internal request into one of our Durable Object classes. */
export function callDO(env: Env, className: string, id: string, path: string, init: DOCall = {}): Promise<Response> {
  const headers = new Headers(init.headers ?? {});
  headers.set("X-Rork-DO-Class", className);
  headers.set("X-Rork-DO-Id", id);
  if (init.body !== undefined) headers.set("Content-Type", "application/json");
  return env.DO.fetch(
    new Request(`https://internal${path}`, {
      method: init.method ?? (init.body !== undefined ? "POST" : "GET"),
      headers,
      body: init.body !== undefined ? JSON.stringify(init.body) : undefined,
    }),
  );
}
