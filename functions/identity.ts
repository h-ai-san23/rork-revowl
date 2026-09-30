import { DurableObject } from "cloudflare:workers";
import { callDO, type Env } from "./_lib/env";
import { errorResponse, HttpError, json, readJson, unwrap } from "./_lib/http";
import { newId } from "./_lib/util";

export const SESSION_TTL_MS = 60 * 86_400_000;

/**
 * `Identity:<provider>:<subject>` → account id. Get-or-create is atomic because a
 * single DO instance serializes requests for one Apple subject.
 */
export class Identity extends DurableObject<Env> {
  override async fetch(request: Request): Promise<Response> {
    try {
      const path = new URL(request.url).pathname;
      if (path === "/resolve" && request.method === "POST") {
        const body = await readJson<{ email: string | null; name: string | null }>(request);
        let accountId = await this.ctx.storage.get<string>("accountId");
        let created = false;
        if (!accountId) {
          accountId = newId("acc");
          await unwrap(
            await callDO(this.env, "Account", accountId, "/init", {
              body: { identity: this.ctx.id.name, email: body.email, name: body.name },
            }),
          );
          await this.ctx.storage.put("accountId", accountId);
          created = true;
        }
        return json({ accountId, created });
      }
      if (path === "/delete" && request.method === "POST") {
        await this.ctx.storage.deleteAll();
        return json({ ok: true });
      }
      throw new HttpError(404, "not_found", "Unknown identity route.");
    } catch (e) {
      return errorResponse(e);
    }
  }
}

/** `Session:<sha256(token)>` — opaque bearer session. Only the hash is ever stored. */
export class Session extends DurableObject<Env> {
  override async fetch(request: Request): Promise<Response> {
    try {
      const path = new URL(request.url).pathname;
      if (path === "/create" && request.method === "POST") {
        const body = await readJson<{ accountId: string }>(request);
        const now = Date.now();
        await this.ctx.storage.put("session", { accountId: body.accountId, createdAt: now, expiresAt: now + SESSION_TTL_MS });
        return json({ ok: true, expiresAt: now + SESSION_TTL_MS });
      }
      if (path === "/check") {
        const s = await this.ctx.storage.get<{ accountId: string; createdAt: number; expiresAt: number }>("session");
        if (!s || s.expiresAt < Date.now()) {
          if (s) await this.ctx.storage.deleteAll();
          throw new HttpError(401, "unauthenticated", "Your session has ended. Please sign in again.");
        }
        // Sliding expiry, refreshed at most daily.
        if (s.expiresAt - Date.now() < SESSION_TTL_MS - 86_400_000) {
          s.expiresAt = Date.now() + SESSION_TTL_MS;
          await this.ctx.storage.put("session", s);
        }
        return json({ accountId: s.accountId });
      }
      if (path === "/revoke" && request.method === "POST") {
        await this.ctx.storage.deleteAll();
        return json({ ok: true });
      }
      throw new HttpError(404, "not_found", "Unknown session route.");
    } catch (e) {
      return errorResponse(e);
    }
  }
}

export type AccountProperty = { propertyId: string; role: "owner" | "manager" | "viewer"; name: string; addedAt: number };
type AccountRecord = {
  id: string;
  identity: string;
  email: string | null;
  name: string | null;
  createdAt: number;
  properties: AccountProperty[];
  sessions: string[];
};

/** `Account:<accountId>` — profile, property memberships and session hashes. */
export class Account extends DurableObject<Env> {
  private async load(): Promise<AccountRecord> {
    const a = await this.ctx.storage.get<AccountRecord>("account");
    if (!a) throw new HttpError(404, "account_not_found", "Account not found.");
    return a;
  }

  override async fetch(request: Request): Promise<Response> {
    try {
      const path = new URL(request.url).pathname;
      if (path === "/init" && request.method === "POST") {
        const body = await readJson<{ identity: string; email: string | null; name: string | null }>(request);
        const existing = await this.ctx.storage.get<AccountRecord>("account");
        if (existing) return json(existing);
        const rec: AccountRecord = {
          id: this.ctx.id.name ?? "",
          identity: body.identity,
          email: body.email,
          name: body.name,
          createdAt: Date.now(),
          properties: [],
          sessions: [],
        };
        await this.ctx.storage.put("account", rec);
        return json(rec);
      }
      if (path === "/me") {
        const a = await this.load();
        return json({ id: a.id, email: a.email, name: a.name, createdAt: a.createdAt, properties: a.properties });
      }
      if (path === "/update-profile" && request.method === "POST") {
        const body = await readJson<{ email?: string | null; name?: string | null }>(request);
        const a = await this.load();
        if (body.name && !a.name) a.name = body.name.slice(0, 120);
        if (body.email && !a.email) a.email = body.email.slice(0, 200);
        await this.ctx.storage.put("account", a);
        return json({ ok: true });
      }
      if (path === "/add-session" && request.method === "POST") {
        const { hash } = await readJson<{ hash: string }>(request);
        const a = await this.load();
        a.sessions = [...a.sessions.slice(-19), hash];
        await this.ctx.storage.put("account", a);
        return json({ ok: true });
      }
      if (path === "/remove-session" && request.method === "POST") {
        const { hash } = await readJson<{ hash: string }>(request);
        const a = await this.load();
        a.sessions = a.sessions.filter((h) => h !== hash);
        await this.ctx.storage.put("account", a);
        return json({ ok: true });
      }
      if (path === "/add-property" && request.method === "POST") {
        const body = await readJson<AccountProperty>(request);
        const a = await this.load();
        a.properties = [...a.properties.filter((p) => p.propertyId !== body.propertyId), { ...body, addedAt: Date.now() }];
        await this.ctx.storage.put("account", a);
        return json({ ok: true });
      }
      if (path === "/rename-property" && request.method === "POST") {
        const body = await readJson<{ propertyId: string; name: string }>(request);
        const a = await this.load();
        a.properties = a.properties.map((p) => (p.propertyId === body.propertyId ? { ...p, name: body.name } : p));
        await this.ctx.storage.put("account", a);
        return json({ ok: true });
      }
      if (path === "/remove-property" && request.method === "POST") {
        const body = await readJson<{ propertyId: string }>(request);
        const a = await this.load();
        a.properties = a.properties.filter((p) => p.propertyId !== body.propertyId);
        await this.ctx.storage.put("account", a);
        return json({ ok: true });
      }
      if (path === "/delete" && request.method === "POST") {
        const a = await this.load();
        for (const p of a.properties) {
          const res = await callDO(this.env, "Property", p.propertyId, p.role === "owner" ? "/internal/destroy" : "/internal/remove-member", {
            body: { accountId: a.id },
            headers: { "X-Account-Id": a.id },
          });
          if (!res.ok) console.warn("property cleanup failed", p.propertyId, res.status);
        }
        for (const h of a.sessions) await callDO(this.env, "Session", h, "/revoke", { body: {} });
        await callDO(this.env, "Identity", a.identity, "/delete", { body: {} });
        await this.ctx.storage.deleteAll();
        return json({ ok: true });
      }
      throw new HttpError(404, "not_found", "Unknown account route.");
    } catch (e) {
      return errorResponse(e);
    }
  }
}

/** `Invite:<code>` — single-use team invitation, valid for 7 days. */
export class Invite extends DurableObject<Env> {
  override async fetch(request: Request): Promise<Response> {
    try {
      const path = new URL(request.url).pathname;
      if (path === "/create" && request.method === "POST") {
        const body = await readJson<{ propertyId: string; role: "manager" | "viewer"; propertyName: string; createdBy: string }>(request);
        await this.ctx.storage.put("invite", { ...body, expiresAt: Date.now() + 7 * 86_400_000, usedBy: null });
        return json({ ok: true });
      }
      if (path === "/peek") {
        const inv = await this.ctx.storage.get<{ propertyId: string; role: string; propertyName: string; expiresAt: number; usedBy: string | null }>("invite");
        if (!inv || inv.expiresAt < Date.now() || inv.usedBy) throw new HttpError(404, "invite_invalid", "This invitation has expired or was already used.");
        return json({ propertyId: inv.propertyId, role: inv.role, propertyName: inv.propertyName });
      }
      if (path === "/consume" && request.method === "POST") {
        const { accountId } = await readJson<{ accountId: string }>(request);
        const inv = await this.ctx.storage.get<{ propertyId: string; role: string; propertyName: string; expiresAt: number; usedBy: string | null }>("invite");
        if (!inv || inv.expiresAt < Date.now() || inv.usedBy) throw new HttpError(404, "invite_invalid", "This invitation has expired or was already used.");
        inv.usedBy = accountId;
        await this.ctx.storage.put("invite", inv);
        return json({ propertyId: inv.propertyId, role: inv.role, propertyName: inv.propertyName });
      }
      if (path === "/revoke" && request.method === "POST") {
        await this.ctx.storage.deleteAll();
        return json({ ok: true });
      }
      throw new HttpError(404, "not_found", "Unknown invite route.");
    } catch (e) {
      return errorResponse(e);
    }
  }
}
