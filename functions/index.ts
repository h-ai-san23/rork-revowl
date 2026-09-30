/**
 * revOWL backend — Cloudflare Worker entrypoint.
 *
 * Routing, authentication and tenant isolation live here. All property state lives in
 * one `Property` Durable Object per hotel; the Worker only forwards a request to a
 * property after confirming the signed-in account is a member of it.
 */
import { verifyAppleIdentityToken } from "./_lib/apple";
import { callDO, DEFAULT_APPLE_AUDIENCES, type Env } from "./_lib/env";
import { errorResponse, HttpError, json, readJson, unwrap } from "./_lib/http";
import { publicPlans, TRIAL_DAYS } from "./_lib/plans";
import { clampString, newId, randomSecret, safeEqual, sha256Hex } from "./_lib/util";
import type { AccountProperty } from "./identity";

export { Account, Identity, Invite, Session } from "./identity";
export { Property } from "./property";

const API_VERSION = "2026-09-30";
const MAX_PROPERTIES_PER_ACCOUNT = 10;

type Me = { id: string; email: string | null; name: string | null; createdAt: number; properties: AccountProperty[] };

async function authenticate(request: Request, env: Env): Promise<{ accountId: string; tokenHash: string }> {
  const header = request.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
  if (!token.startsWith("rvs_") || token.length < 30) throw new HttpError(401, "unauthenticated", "Please sign in.");
  const tokenHash = await sha256Hex(token);
  const { accountId } = await unwrap<{ accountId: string }>(await callDO(env, "Session", tokenHash, "/check"));
  return { accountId, tokenHash };
}

async function issueSession(env: Env, accountId: string): Promise<{ token: string; expiresAt: number }> {
  const token = `rvs_${randomSecret(32)}`;
  const hash = await sha256Hex(token);
  const { expiresAt } = await unwrap<{ expiresAt: number }>(await callDO(env, "Session", hash, "/create", { body: { accountId } }));
  await unwrap(await callDO(env, "Account", accountId, "/add-session", { body: { hash } }));
  return { token, expiresAt };
}

async function loadMe(env: Env, accountId: string): Promise<Me> {
  return unwrap<Me>(await callDO(env, "Account", accountId, "/me"));
}

async function signInResponse(env: Env, identityKey: string, email: string | null, name: string | null) {
  const { accountId, created } = await unwrap<{ accountId: string; created: boolean }>(
    await callDO(env, "Identity", identityKey, "/resolve", { body: { email, name } }),
  );
  if (!created && (email || name)) {
    await callDO(env, "Account", accountId, "/update-profile", { body: { email, name } });
  }
  const session = await issueSession(env, accountId);
  const me = await loadMe(env, accountId);
  return json({ token: session.token, expiresAt: session.expiresAt, isNewAccount: created, account: me });
}

async function handleAppleSignIn(request: Request, env: Env): Promise<Response> {
  const body = await readJson<{ identityToken?: string; nonce?: string; fullName?: string | null; email?: string | null }>(request);
  if (!body.identityToken || typeof body.identityToken !== "string") throw new HttpError(400, "missing_token", "Apple sign-in didn't return a token.");
  if (!body.nonce || typeof body.nonce !== "string" || body.nonce.length < 16) throw new HttpError(400, "missing_nonce", "Apple sign-in is missing its security nonce.");
  const audiences = (env.APPLE_AUDIENCES ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  const identity = await verifyAppleIdentityToken(body.identityToken, audiences.length ? audiences : DEFAULT_APPLE_AUDIENCES, body.nonce);
  // Apple only sends the name on the very first authorization, from the client.
  const name = clampString(body.fullName, 120);
  return signInResponse(env, `apple:${identity.sub}`, identity.email, name);
}

/**
 * Device sign-in for development and the cloud simulator, where Sign in with Apple
 * isn't available. Creates an isolated account bound to a random device secret.
 * Disable in production by setting DISABLE_DEVICE_AUTH=true.
 */
async function handleDeviceSignIn(request: Request, env: Env): Promise<Response> {
  if (env.DISABLE_DEVICE_AUTH === "true") throw new HttpError(403, "device_auth_disabled", "Please use Sign in with Apple.");
  const body = await readJson<{ deviceSecret?: string; name?: string }>(request);
  if (typeof body.deviceSecret !== "string" || body.deviceSecret.length < 32 || body.deviceSecret.length > 200) {
    throw new HttpError(400, "invalid_device", "Device sign-in needs a valid device secret.");
  }
  const key = `device:${await sha256Hex(body.deviceSecret)}`;
  return signInResponse(env, key, null, clampString(body.name, 120));
}

async function requireMembership(env: Env, accountId: string, propertyId: string): Promise<{ me: Me; membership: AccountProperty }> {
  const me = await loadMe(env, accountId);
  const membership = me.properties.find((p) => p.propertyId === propertyId);
  if (!membership) throw new HttpError(404, "property_not_found", "Property not found.");
  return { me, membership };
}

async function forwardToProperty(request: Request, env: Env, accountId: string, propertyId: string, subPath: string): Promise<Response> {
  const url = new URL(request.url);
  const target = new URL(`https://internal${subPath || "/"}`);
  target.search = url.search;
  const headers = new Headers();
  headers.set("X-Rork-DO-Class", "Property");
  headers.set("X-Rork-DO-Id", propertyId);
  headers.set("X-Account-Id", accountId);
  const ct = request.headers.get("Content-Type");
  if (ct) headers.set("Content-Type", ct);
  const hasBody = !["GET", "HEAD"].includes(request.method);
  return env.DO.fetch(new Request(target.toString(), { method: request.method, headers, body: hasBody ? await request.text() : undefined }));
}

async function createProperty(request: Request, env: Env, accountId: string): Promise<Response> {
  const me = await loadMe(env, accountId);
  if (me.properties.filter((p) => p.role === "owner").length >= MAX_PROPERTIES_PER_ACCOUNT) {
    throw new HttpError(400, "property_limit", "You've reached the number of properties one account can own.");
  }
  const body = await readJson<Record<string, unknown>>(request);
  const name = clampString(body.name, 160);
  if (!name) throw new HttpError(400, "invalid_name", "Enter your property's name.");
  const propertyId = newId("prop", 18);
  const profile = await unwrap<{ id: string; name: string }>(
    await callDO(env, "Property", propertyId, "/internal/init", {
      body: { ownerId: accountId, ownerName: me.name, ownerEmail: me.email, profile: { ...body, name } },
    }),
  );
  await unwrap(await callDO(env, "Account", accountId, "/add-property", { body: { propertyId, role: "owner", name: profile.name } }));
  const overview = await callDO(env, "Property", propertyId, "/", { headers: { "X-Account-Id": accountId } });
  return new Response(overview.body, { status: 201, headers: { "Content-Type": "application/json" } });
}

async function acceptInvite(env: Env, accountId: string, code: string): Promise<Response> {
  const me = await loadMe(env, accountId);
  const inv = await unwrap<{ propertyId: string; role: "manager" | "viewer"; propertyName: string }>(await callDO(env, "Invite", code, "/peek"));
  if (me.properties.some((p) => p.propertyId === inv.propertyId)) return json({ propertyId: inv.propertyId, alreadyMember: true });
  await unwrap(await callDO(env, "Property", inv.propertyId, "/internal/join", { body: { accountId, role: inv.role, name: me.name, email: me.email } }));
  await unwrap(await callDO(env, "Invite", code, "/consume", { body: { accountId } }));
  await unwrap(await callDO(env, "Account", accountId, "/add-property", { body: { propertyId: inv.propertyId, role: inv.role, name: inv.propertyName } }));
  return json({ propertyId: inv.propertyId, alreadyMember: false });
}

async function revenueCatWebhook(request: Request, env: Env): Promise<Response> {
  const expected = env.REVENUECAT_WEBHOOK_AUTH;
  if (!expected) throw new HttpError(503, "webhook_unconfigured", "Webhook is not configured.");
  const got = request.headers.get("Authorization") ?? "";
  if (!safeEqual(got, expected) && !safeEqual(got, `Bearer ${expected}`)) throw new HttpError(401, "unauthorized", "Invalid webhook authorization.");
  const body = await readJson<{ event?: { app_user_id?: string; original_app_user_id?: string; aliases?: string[]; type?: string } }>(request);
  const ids = new Set([body.event?.app_user_id, body.event?.original_app_user_id, ...(body.event?.aliases ?? [])].filter((x): x is string => typeof x === "string" && /^prop_[a-z0-9]+$/.test(x)));
  for (const id of ids) {
    const res = await callDO(env, "Property", id, "/internal/billing-sync", { body: {} });
    if (!res.ok && res.status !== 404) console.warn("webhook billing sync failed", res.status);
  }
  return json({ ok: true, synced: ids.size });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      const url = new URL(request.url);
      const path = url.pathname.replace(/\/+$/, "") || "/";
      const method = request.method;

      if (method === "OPTIONS") return new Response(null, { status: 204 });
      if (path === "/" || path === "/v1/health") {
        return json({
          ok: true,
          service: "revowl",
          apiVersion: API_VERSION,
          now: new Date().toISOString(),
          capabilities: {
            ai: !!env.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY,
            billingVerification: !!(env.REVENUECAT_SECRET_API_KEY || env.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY || env.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY),
            billingWebhook: !!env.REVENUECAT_WEBHOOK_AUTH,
            deviceSignIn: env.DISABLE_DEVICE_AUTH !== "true",
          },
        });
      }
      if (path === "/v1/plans" && method === "GET") {
        return json({ trialDays: TRIAL_DAYS, currency: "USD", billingPeriod: "monthly", plans: publicPlans() }, 200, { "Cache-Control": "public, max-age=300" });
      }
      if (path === "/v1/auth/apple" && method === "POST") return await handleAppleSignIn(request, env);
      if (path === "/v1/auth/device" && method === "POST") return await handleDeviceSignIn(request, env);
      if (path === "/v1/webhooks/revenuecat" && method === "POST") return await revenueCatWebhook(request, env);

      if (!path.startsWith("/v1/")) throw new HttpError(404, "not_found", "Not found.");

      const { accountId, tokenHash } = await authenticate(request, env);

      if (path === "/v1/auth/signout" && method === "POST") {
        await callDO(env, "Session", tokenHash, "/revoke", { body: {} });
        await callDO(env, "Account", accountId, "/remove-session", { body: { hash: tokenHash } });
        return json({ ok: true });
      }
      if (path === "/v1/me" && method === "GET") return json(await loadMe(env, accountId));
      if (path === "/v1/me" && method === "DELETE") {
        await unwrap(await callDO(env, "Account", accountId, "/delete", { body: {} }));
        return json({ ok: true });
      }
      if (path === "/v1/properties" && method === "POST") return await createProperty(request, env, accountId);

      const invite = path.match(/^\/v1\/invites\/([A-Z0-9]{6,20})\/accept$/);
      if (invite && method === "POST") return await acceptInvite(env, accountId, invite[1]);

      const prop = path.match(/^\/v1\/properties\/(prop_[a-z0-9]+)(\/.*)?$/);
      if (prop) {
        const [, propertyId, sub] = prop;
        await requireMembership(env, accountId, propertyId);
        const res = await forwardToProperty(request, env, accountId, propertyId, sub ?? "/");
        if (res.status === 404 && (sub ?? "/") === "/" && method === "GET") {
          // Property was deleted by its owner: clean up the stale membership.
          await callDO(env, "Account", accountId, "/remove-property", { body: { propertyId } });
        }
        return res;
      }

      throw new HttpError(404, "not_found", "Not found.");
    } catch (e) {
      return errorResponse(e);
    }
  },
} satisfies ExportedHandler<Env>;
