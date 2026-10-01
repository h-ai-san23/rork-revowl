import { DurableObject } from "cloudflare:workers";
import { fetchSubscriber, type BillingSnapshot } from "./_lib/billing";
import { importPerformanceCsv } from "./_lib/csv";
import { callDO, type Env } from "./_lib/env";
import { discoverEvents, normalizeTitle } from "./_lib/events";
import { errorResponse, HttpError, json, readJson } from "./_lib/http";
import { marketDays, validateDaily, type DailyPerformance, type DataKind, type OtbSnapshotRow, type RateObservation } from "./_lib/metrics";
import { askOrev, buildBriefing, narrate, type AskTurn } from "./_lib/orev";
import { effectivePlan, orevAllowance, PLANS, TRIAL_DAYS, type BillingState, type PlanId } from "./_lib/plans";
import { validatePublicUrl } from "./_lib/safe-fetch";
import type { Briefing, Competitor, EventRow, EventStatus, FieldSource, MarketSummary, Profile, PropertyReader } from "./_lib/types";
import { extractWebsite } from "./_lib/website";
import { fetchRates, matchHotel, sampleStayDates, type MatchResult } from "./_lib/xotelo";
import {
  addDays,
  clampString,
  dateRange,
  finiteNumber,
  isIsoDate,
  isValidTimeZone,
  mapLimit,
  monthKey,
  newId,
  todayIn,
} from "./_lib/util";

type Role = "owner" | "manager" | "viewer";
type Member = { accountId: string; role: Role; name: string | null; email: string | null; addedAt: number; active: boolean };

const SCHEMA_VERSION = 1;

/** Ordered, append-only migrations. Never edit a shipped migration; add a new one. */
const MIGRATIONS: string[][] = [
  [
    `CREATE TABLE IF NOT EXISTS members (account_id TEXT PRIMARY KEY, role TEXT NOT NULL, name TEXT, email TEXT, added_at INTEGER NOT NULL, active INTEGER NOT NULL DEFAULT 1)`,
    `CREATE TABLE IF NOT EXISTS performance (date TEXT NOT NULL, kind TEXT NOT NULL, rooms_available INTEGER NOT NULL, rooms_sold INTEGER NOT NULL, room_revenue REAL, source TEXT NOT NULL, captured_at INTEGER NOT NULL, PRIMARY KEY (date, kind))`,
    `CREATE TABLE IF NOT EXISTS otb_snapshots (as_of TEXT NOT NULL, stay_date TEXT NOT NULL, rooms_sold INTEGER NOT NULL, room_revenue REAL, source TEXT NOT NULL, PRIMARY KEY (as_of, stay_date))`,
    `CREATE TABLE IF NOT EXISTS competitors (id TEXT PRIMARY KEY, name TEXT NOT NULL, xotelo_key TEXT, latitude REAL, longitude REAL, distance_km REAL, rating REAL, priority INTEGER NOT NULL, active INTEGER NOT NULL DEFAULT 1, added_at INTEGER NOT NULL)`,
    `CREATE TABLE IF NOT EXISTS rate_latest (hotel_ref TEXT NOT NULL, stay_date TEXT NOT NULL, rate REAL NOT NULL, channel TEXT NOT NULL, currency TEXT NOT NULL, observed_at INTEGER NOT NULL, manual INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (hotel_ref, stay_date))`,
    `CREATE TABLE IF NOT EXISTS rate_history (id INTEGER PRIMARY KEY AUTOINCREMENT, hotel_ref TEXT NOT NULL, stay_date TEXT NOT NULL, rate REAL NOT NULL, channel TEXT NOT NULL, currency TEXT NOT NULL, observed_at INTEGER NOT NULL, manual INTEGER NOT NULL DEFAULT 0)`,
    `CREATE INDEX IF NOT EXISTS rate_history_ref ON rate_history (hotel_ref, stay_date, observed_at)`,
    `CREATE TABLE IF NOT EXISTS events (id TEXT PRIMARY KEY, title TEXT NOT NULL, start_date TEXT NOT NULL, end_date TEXT NOT NULL, venue TEXT, category TEXT NOT NULL, source_url TEXT, source_title TEXT, expected_attendance INTEGER, source_reachable INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL, origin TEXT NOT NULL, dedupe_key TEXT NOT NULL, created_at INTEGER NOT NULL)`,
    `CREATE INDEX IF NOT EXISTS events_dates ON events (start_date, end_date)`,
    `CREATE TABLE IF NOT EXISTS usage (month TEXT NOT NULL, metric TEXT NOT NULL, count INTEGER NOT NULL DEFAULT 0, cost_usd REAL NOT NULL DEFAULT 0, PRIMARY KEY (month, metric))`,
    `CREATE TABLE IF NOT EXISTS ask_log (id TEXT PRIMARY KEY, account_id TEXT NOT NULL, question TEXT NOT NULL, answer TEXT NOT NULL, mood TEXT NOT NULL, evidence TEXT NOT NULL, follow_ups TEXT NOT NULL, created_at INTEGER NOT NULL)`,
    `CREATE TABLE IF NOT EXISTS audit (id INTEGER PRIMARY KEY AUTOINCREMENT, at INTEGER NOT NULL, account_id TEXT, action TEXT NOT NULL, detail TEXT)`,
    `CREATE TABLE IF NOT EXISTS imports (id TEXT PRIMARY KEY, at INTEGER NOT NULL, account_id TEXT, kind TEXT NOT NULL, source TEXT NOT NULL, rows INTEGER NOT NULL, issues INTEGER NOT NULL)`,
  ],
];

const SETUP_STEPS = ["property", "website", "confirm", "rooms", "locale", "import", "competitors", "goals", "overview", "plans", "briefing", "done"];
const GOALS = ["grow_revpar", "fill_midweek", "raise_adr", "beat_compset", "reduce_ota", "understand_events", "save_time"];
const CURRENCY = /^[A-Z]{3}$/;

export class Property extends DurableObject<Env> {
  private sql: SqlStorage;

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;
    ctx.blockConcurrencyWhile(async () => {
      this.migrate();
    });
  }

  private migrate(): void {
    this.sql.exec(`CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)`);
    const row = this.sql.exec<{ value: string }>(`SELECT value FROM meta WHERE key = 'schema_version'`).toArray()[0];
    let version = row ? Number(row.value) : 0;
    while (version < MIGRATIONS.length) {
      for (const stmt of MIGRATIONS[version]) this.sql.exec(stmt);
      version++;
      this.sql.exec(`INSERT INTO meta (key, value) VALUES ('schema_version', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value`, String(version));
    }
    if (version !== SCHEMA_VERSION) console.warn("schema version mismatch", version, SCHEMA_VERSION);
  }

  /* ---------------------------------------------------------------- */
  /* Small storage helpers                                            */
  /* ---------------------------------------------------------------- */

  private meta(key: string): string | null {
    return this.sql.exec<{ value: string }>(`SELECT value FROM meta WHERE key = ?`, key).toArray()[0]?.value ?? null;
  }

  private setMeta(key: string, value: string): void {
    this.sql.exec(`INSERT INTO meta (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value`, key, value);
  }

  private metaJson<T>(key: string): T | null {
    const v = this.meta(key);
    if (!v) return null;
    try {
      return JSON.parse(v) as T;
    } catch {
      return null;
    }
  }

  private bumpData(): void {
    this.setMeta("data_version", String(Date.now()));
  }

  private audit(accountId: string | null, action: string, detail?: unknown): void {
    this.sql.exec(`INSERT INTO audit (at, account_id, action, detail) VALUES (?, ?, ?, ?)`, Date.now(), accountId, action, detail === undefined ? null : JSON.stringify(detail).slice(0, 2000));
    this.sql.exec(`DELETE FROM audit WHERE id NOT IN (SELECT id FROM audit ORDER BY id DESC LIMIT 1000)`);
  }

  private profile(): Profile {
    const p = this.metaJson<Profile>("profile");
    if (!p) throw new HttpError(404, "property_not_found", "This property no longer exists.");
    return p;
  }

  private saveProfile(p: Profile): void {
    p.updatedAt = Date.now();
    this.setMeta("profile", JSON.stringify(p));
  }

  private billing(): BillingSnapshot | null {
    return this.metaJson<BillingSnapshot>("billing");
  }

  private planState(): { plan: PlanId; state: BillingState; billing: BillingSnapshot | null } {
    const b = this.billing();
    if (!b) return { plan: "none", state: "none", billing: null };
    let state = b.state;
    if ((state === "active" || state === "trial") && b.expiresAt !== null && b.expiresAt < Date.now() - 6 * 3_600_000) state = "expired";
    return { plan: effectivePlan(b.plan, state), state, billing: b };
  }

  private limits() {
    return PLANS[this.planState().plan].limits;
  }

  private today(): string {
    return todayIn(this.profile().timeZone);
  }

  private usage(month = monthKey()): { orevAnswers: number; costUsd: number } {
    const rows = this.sql.exec<{ metric: string; count: number; cost_usd: number }>(`SELECT metric, count, cost_usd FROM usage WHERE month = ?`, month).toArray();
    return {
      orevAnswers: rows.find((r) => r.metric === "orev_answers")?.count ?? 0,
      costUsd: rows.reduce((a, r) => a + r.cost_usd, 0),
    };
  }

  private meter(metric: string, count: number, costUsd: number): void {
    this.sql.exec(
      `INSERT INTO usage (month, metric, count, cost_usd) VALUES (?, ?, ?, ?) ON CONFLICT(month, metric) DO UPDATE SET count = count + excluded.count, cost_usd = cost_usd + excluded.cost_usd`,
      monthKey(),
      metric,
      count,
      costUsd,
    );
  }

  /** Throws when the property's variable-cost ceiling for this month is reached. */
  private assertBudget(label: string): void {
    const ceiling = this.limits().monthlyCostCeilingUsd;
    if (this.usage().costUsd >= ceiling) {
      throw new HttpError(429, "monthly_budget_reached", `${label} is paused until next month to keep your plan free of surprise charges.`, { ceilingUsd: ceiling });
    }
  }

  /* ---------------------------------------------------------------- */
  /* Members & access                                                 */
  /* ---------------------------------------------------------------- */

  private members(): Member[] {
    return this.sql
      .exec<{ account_id: string; role: Role; name: string | null; email: string | null; added_at: number; active: number }>(`SELECT * FROM members ORDER BY added_at`)
      .toArray()
      .map((m) => ({ accountId: m.account_id, role: m.role, name: m.name, email: m.email, addedAt: m.added_at, active: m.active === 1 }));
  }

  private requireRole(accountId: string | null, min: Role): Member {
    if (!accountId) throw new HttpError(401, "unauthenticated", "Please sign in.");
    const m = this.members().find((x) => x.accountId === accountId);
    if (!m) throw new HttpError(404, "property_not_found", "Property not found.");
    if (!m.active && m.role !== "owner") throw new HttpError(403, "member_inactive", "Your access to this property is paused. Ask the owner to restore it.");
    const order: Role[] = ["viewer", "manager", "owner"];
    if (order.indexOf(m.role) < order.indexOf(min)) throw new HttpError(403, "forbidden", min === "owner" ? "Only the property owner can do this." : "You don't have permission to change this.");
    return m;
  }

  /* ---------------------------------------------------------------- */
  /* Reader for Orev (read-only)                                      */
  /* ---------------------------------------------------------------- */

  private performanceRows(start: string, end: string): DailyPerformance[] {
    return this.sql
      .exec<{ date: string; kind: DataKind; rooms_available: number; rooms_sold: number; room_revenue: number | null; source: string; captured_at: number }>(
        `SELECT * FROM performance WHERE date >= ? AND date <= ? ORDER BY date`,
        start,
        end,
      )
      .toArray()
      .map((r) => ({ date: r.date, kind: r.kind, roomsAvailable: r.rooms_available, roomsSold: r.rooms_sold, roomRevenue: r.room_revenue, source: r.source, capturedAt: r.captured_at }));
  }

  private snapshotRows(): OtbSnapshotRow[] {
    return this.sql
      .exec<{ as_of: string; stay_date: string; rooms_sold: number; room_revenue: number | null }>(`SELECT as_of, stay_date, rooms_sold, room_revenue FROM otb_snapshots ORDER BY as_of`)
      .toArray()
      .map((r) => ({ asOf: r.as_of, stayDate: r.stay_date, roomsSold: r.rooms_sold, roomRevenue: r.room_revenue }));
  }

  private competitors(): Competitor[] {
    return this.sql
      .exec<{ id: string; name: string; xotelo_key: string | null; latitude: number | null; longitude: number | null; distance_km: number | null; rating: number | null; priority: number; active: number; added_at: number }>(
        `SELECT * FROM competitors ORDER BY priority, added_at`,
      )
      .toArray()
      .map((c) => ({
        id: c.id,
        name: c.name,
        xoteloKey: c.xotelo_key,
        latitude: c.latitude,
        longitude: c.longitude,
        distanceKm: c.distance_km,
        rating: c.rating,
        priority: c.priority,
        active: c.active === 1,
        addedAt: c.added_at,
      }));
  }

  private eventRows(start: string, end: string): EventRow[] {
    return this.sql
      .exec<{
        id: string;
        title: string;
        start_date: string;
        end_date: string;
        venue: string | null;
        category: string;
        source_url: string | null;
        source_title: string | null;
        expected_attendance: number | null;
        source_reachable: number;
        status: EventStatus;
        origin: "discovered" | "manual";
        created_at: number;
      }>(`SELECT * FROM events WHERE end_date >= ? AND start_date <= ? ORDER BY start_date, title`, start, end)
      .toArray()
      .map((e) => ({
        id: e.id,
        title: e.title,
        startDate: e.start_date,
        endDate: e.end_date,
        venue: e.venue,
        category: e.category,
        sourceUrl: e.source_url,
        sourceTitle: e.source_title,
        expectedAttendance: e.expected_attendance,
        sourceReachable: e.source_reachable === 1,
        status: e.status,
        origin: e.origin,
        createdAt: e.created_at,
      }));
  }

  private marketSummary(start: string, end: string): MarketSummary {
    const p = this.profile();
    const comps = this.competitors();
    const rows = this.sql
      .exec<{ hotel_ref: string; stay_date: string; rate: number; channel: string; currency: string; observed_at: number; manual: number }>(
        `SELECT * FROM rate_latest WHERE stay_date >= ? AND stay_date <= ?`,
        start,
        end,
      )
      .toArray()
      .filter((r) => r.currency === p.currency);
    const obs: RateObservation[] = rows.map((r) => ({ hotelKey: r.hotel_ref, stayDate: r.stay_date, channel: r.channel, rate: r.rate, currency: r.currency, observedAt: r.observed_at }));
    const active = comps.filter((c) => c.active);
    const byHotel: MarketSummary["byHotel"] = {};
    for (const r of rows) {
      byHotel[r.hotel_ref] ??= {};
      byHotel[r.hotel_ref][r.stay_date] = { rate: r.rate, channel: r.channel, observedAt: r.observed_at, manual: r.manual === 1 };
    }
    const lastRefresh = Number(this.meta("rates_last_refresh") ?? "0") || null;
    return {
      provider: "Xotelo public rates",
      providerStatus: "beta",
      currency: p.currency,
      lastRefreshAt: lastRefresh,
      ownTracked: !!p.xoteloKey || !!byHotel.own,
      competitors: comps.map((c) => ({ id: c.id, name: c.name, hasData: !!byHotel[c.id], active: c.active })),
      days: marketDays(obs, "own", active.map((c) => c.id), dateRange(start, end)),
      byHotel,
    };
  }

  private reader(): PropertyReader {
    return {
      profile: () => this.profile(),
      today: () => this.today(),
      performance: (s, e) => this.performanceRows(s, e),
      snapshots: () => this.snapshotRows(),
      market: (s, e) => this.marketSummary(s, e),
      events: (s, e) => this.eventRows(s, e),
      plan: () => this.planState(),
    };
  }

  /* ---------------------------------------------------------------- */
  /* Overview payload                                                 */
  /* ---------------------------------------------------------------- */

  private overview(accountId: string) {
    const p = this.profile();
    const ps = this.planState();
    const limits = PLANS[ps.plan].limits;
    const usage = this.usage();
    const me = this.members().find((m) => m.accountId === accountId);
    const comps = this.competitors();
    const perfCount = this.sql.exec<{ n: number }>(`SELECT COUNT(*) AS n FROM performance WHERE source != 'sample'`).one().n;
    const sampleCount = this.sql.exec<{ n: number }>(`SELECT COUNT(*) AS n FROM performance WHERE source = 'sample'`).one().n;
    return {
      profile: p,
      role: me?.role ?? "viewer",
      plan: {
        id: ps.plan,
        purchasedPlan: ps.billing?.plan ?? "none",
        state: ps.state,
        expiresAt: ps.billing?.expiresAt ?? null,
        willRenew: ps.billing?.willRenew ?? false,
        trialUsed: ps.billing?.trialUsed ?? false,
        billingIssue: ps.billing?.billingIssue ?? false,
        managementUrl: ps.billing?.managementUrl ?? null,
        verifiedAt: ps.billing?.verifiedAt ?? null,
        trialDays: TRIAL_DAYS,
        limits,
      },
      usage: {
        month: monthKey(),
        orevAnswersUsed: usage.orevAnswers,
        orevAnswersAllowed: orevAllowance(ps.plan, ps.state),
        budgetReached: usage.costUsd >= limits.monthlyCostCeilingUsd,
      },
      counts: {
        competitors: comps.length,
        activeCompetitors: comps.filter((c) => c.active).length,
        members: this.members().length,
        performanceDays: perfCount,
        sampleDays: sampleCount,
      },
      needsAttention: {
        competitorsOverLimit: comps.filter((c) => c.active).length > limits.competitors,
        membersOverLimit: this.members().filter((m) => m.active).length > limits.teamMembers,
      },
      today: this.today(),
    };
  }

  /* ---------------------------------------------------------------- */
  /* Router                                                            */
  /* ---------------------------------------------------------------- */

  override async fetch(request: Request): Promise<Response> {
    try {
      const url = new URL(request.url);
      const path = url.pathname.replace(/\/+$/, "") || "/";
      const method = request.method;
      const accountId = request.headers.get("X-Account-Id");

      if (path.startsWith("/internal/")) return await this.internal(path, request);

      if (path === "/" && method === "GET") {
        this.requireRole(accountId, "viewer");
        return json(this.overview(accountId!));
      }
      if (path === "/" && method === "DELETE") {
        this.requireRole(accountId, "owner");
        return json(await this.destroy());
      }
      if (path === "/profile" && method === "PATCH") {
        const m = this.requireRole(accountId, "manager");
        return json(this.updateProfile(m.accountId, await readJson<Record<string, unknown>>(request)));
      }
      if (path === "/setup-step" && method === "POST") {
        this.requireRole(accountId, "manager");
        const body = await readJson<{ step?: string; completed?: boolean }>(request);
        const p = this.profile();
        if (body.step && SETUP_STEPS.includes(body.step)) p.setupStep = body.step;
        if (body.completed === true) {
          p.setupCompleted = true;
          p.setupStep = "done";
          await this.scheduleNext();
        }
        this.saveProfile(p);
        return json({ setupStep: p.setupStep, setupCompleted: p.setupCompleted });
      }
      if (path === "/website/extract" && method === "POST") {
        const m = this.requireRole(accountId, "manager");
        const { url: raw } = await readJson<{ url?: string }>(request);
        this.assertBudget("Website reading");
        const extraction = await extractWebsite(this.env, String(raw ?? ""));
        this.meter("website_extract", 1, extraction.costUsd);
        this.setMeta("last_extraction", JSON.stringify(extraction));
        this.audit(m.accountId, "website.extract", { url: extraction.sourceUrl, fields: Object.keys(extraction.fields) });
        return json(extraction);
      }
      if (path === "/match" && method === "POST") {
        this.requireRole(accountId, "manager");
        return json(await this.match(url.searchParams.get("refresh") === "1"));
      }
      if (path === "/listing" && method === "POST") {
        const m = this.requireRole(accountId, "manager");
        const body = await readJson<{ xoteloKey?: string | null; name?: string | null }>(request);
        const p = this.profile();
        const key = body.xoteloKey ?? null;
        if (key !== null && !/^g\d+-d\d+$/.test(key)) throw new HttpError(400, "invalid_listing", "That listing id isn't valid.");
        if (key !== p.xoteloKey) this.sql.exec(`DELETE FROM rate_latest WHERE hotel_ref = 'own' AND manual = 0`);
        p.xoteloKey = key;
        p.xoteloName = key ? clampString(body.name, 160) : null;
        this.saveProfile(p);
        this.audit(m.accountId, "listing.set", { key });
        this.bumpData();
        return json({ xoteloKey: p.xoteloKey, xoteloName: p.xoteloName });
      }

      /* Competitors */
      if (path === "/competitors" && method === "GET") {
        this.requireRole(accountId, "viewer");
        return json({ competitors: this.competitors(), limit: this.limits().competitors });
      }
      if (path === "/competitors" && method === "POST") {
        const m = this.requireRole(accountId, "manager");
        return json(this.addCompetitor(m.accountId, await readJson<Record<string, unknown>>(request)), 201);
      }
      if (path === "/competitors/active" && method === "POST") {
        const m = this.requireRole(accountId, "manager");
        const { ids } = await readJson<{ ids?: string[] }>(request);
        return json(this.setActiveCompetitors(m.accountId, Array.isArray(ids) ? ids : []));
      }
      const compMatch = path.match(/^\/competitors\/(cmp_[a-z0-9]+)$/);
      if (compMatch && method === "DELETE") {
        const m = this.requireRole(accountId, "manager");
        this.sql.exec(`DELETE FROM competitors WHERE id = ?`, compMatch[1]);
        this.sql.exec(`DELETE FROM rate_latest WHERE hotel_ref = ?`, compMatch[1]);
        this.audit(m.accountId, "competitor.remove", { id: compMatch[1] });
        this.bumpData();
        return json({ ok: true });
      }

      /* Performance */
      if (path === "/performance" && method === "GET") {
        this.requireRole(accountId, "viewer");
        const today = this.today();
        const start = isIsoDate(url.searchParams.get("start")) ? url.searchParams.get("start")! : addDays(today, -30);
        const end = isIsoDate(url.searchParams.get("end")) ? url.searchParams.get("end")! : addDays(today, 30);
        return json({ rows: this.performanceRows(start, end), snapshots: this.snapshotRows().filter((s) => s.stayDate >= start && s.stayDate <= end).length, today });
      }
      if (path === "/performance" && method === "POST") {
        const m = this.requireRole(accountId, "manager");
        return json(this.writePerformance(m.accountId, await readJson<{ rows?: unknown[] }>(request)));
      }
      if (path === "/performance/import-csv" && method === "POST") {
        const m = this.requireRole(accountId, "manager");
        return json(this.importCsv(m.accountId, await readJson<{ csv?: string; kind?: string; commit?: boolean; fileName?: string }>(request, 2_000_000)));
      }
      if (path === "/sample-data" && method === "POST") {
        const m = this.requireRole(accountId, "manager");
        return json(this.loadSample(m.accountId));
      }
      if (path === "/sample-data" && method === "DELETE") {
        const m = this.requireRole(accountId, "manager");
        this.sql.exec(`DELETE FROM performance WHERE source = 'sample'`);
        this.sql.exec(`DELETE FROM otb_snapshots WHERE source = 'sample'`);
        this.audit(m.accountId, "sample.remove");
        this.bumpData();
        return json({ ok: true });
      }

      /* Market */
      if (path === "/market" && method === "GET") {
        this.requireRole(accountId, "viewer");
        const today = this.today();
        const horizon = this.limits().rateHorizonDays;
        const start = isIsoDate(url.searchParams.get("start")) ? url.searchParams.get("start")! : today;
        let end = isIsoDate(url.searchParams.get("end")) ? url.searchParams.get("end")! : addDays(today, Math.min(13, horizon - 1));
        if (end > addDays(today, horizon)) end = addDays(today, horizon);
        return json({ ...this.marketSummary(start, end), horizonDays: horizon, refresh: this.refreshInfo() });
      }
      if (path === "/market/refresh" && method === "POST") {
        const m = this.requireRole(accountId, "manager");
        return json(await this.manualRefresh(m.accountId));
      }
      if (path === "/market/manual-rate" && method === "POST") {
        const m = this.requireRole(accountId, "manager");
        return json(this.manualRate(m.accountId, await readJson<{ hotel?: string; stayDate?: string; rate?: number | null }>(request)));
      }

      /* Events */
      if (path === "/events" && method === "GET") {
        this.requireRole(accountId, "viewer");
        const today = this.today();
        const horizon = this.limits().eventHorizonDays;
        const start = isIsoDate(url.searchParams.get("start")) ? url.searchParams.get("start")! : today;
        const maxEnd = addDays(today, horizon);
        let end = isIsoDate(url.searchParams.get("end")) ? url.searchParams.get("end")! : maxEnd;
        if (end > maxEnd) end = maxEnd;
        return json({ events: this.eventRows(start, end), horizonDays: horizon, lastDiscoveryAt: Number(this.meta("events_last_discovery") ?? "0") || null });
      }
      if (path === "/events/discover" && method === "POST") {
        const m = this.requireRole(accountId, "manager");
        return json(await this.discover(m.accountId, true));
      }
      if (path === "/events" && method === "POST") {
        const m = this.requireRole(accountId, "manager");
        return json(this.addEvent(m.accountId, await readJson<Record<string, unknown>>(request)), 201);
      }
      const evMatch = path.match(/^\/events\/(evt_[a-z0-9]+)$/);
      if (evMatch && method === "PATCH") {
        const m = this.requireRole(accountId, "manager");
        const { status } = await readJson<{ status?: string }>(request);
        if (status !== "confirmed" && status !== "dismissed" && status !== "unverified") throw new HttpError(400, "invalid_status", "Unknown event status.");
        this.sql.exec(`UPDATE events SET status = ? WHERE id = ?`, status, evMatch[1]);
        this.audit(m.accountId, "event.status", { id: evMatch[1], status });
        this.bumpData();
        return json({ ok: true });
      }
      if (evMatch && method === "DELETE") {
        const m = this.requireRole(accountId, "manager");
        this.sql.exec(`DELETE FROM events WHERE id = ?`, evMatch[1]);
        this.audit(m.accountId, "event.delete", { id: evMatch[1] });
        this.bumpData();
        return json({ ok: true });
      }

      /* Orev */
      if (path === "/briefing" && method === "GET") {
        this.requireRole(accountId, "viewer");
        return json(await this.briefing(url.searchParams.get("refresh") === "1"));
      }
      if (path === "/ask" && method === "POST") {
        const m = this.requireRole(accountId, "viewer");
        return json(await this.ask(m.accountId, await readJson<{ question?: string; history?: AskTurn[] }>(request)));
      }
      if (path === "/ask/history" && method === "GET") {
        this.requireRole(accountId, "viewer");
        const rows = this.sql
          .exec<{ id: string; question: string; answer: string; mood: string; evidence: string; follow_ups: string; created_at: number }>(
            `SELECT * FROM ask_log WHERE account_id = ? ORDER BY created_at DESC LIMIT 40`,
            accountId,
          )
          .toArray()
          .reverse()
          .map((r) => ({ id: r.id, question: r.question, answer: r.answer, mood: r.mood, evidence: JSON.parse(r.evidence), followUps: JSON.parse(r.follow_ups), createdAt: r.created_at }));
        return json({ items: rows });
      }

      /* Team */
      if (path === "/team" && method === "GET") {
        this.requireRole(accountId, "viewer");
        return json({ members: this.members(), limit: this.limits().teamMembers });
      }
      if (path === "/team/invite" && method === "POST") {
        const m = this.requireRole(accountId, "owner");
        const { role } = await readJson<{ role?: string }>(request);
        const r: Role = role === "viewer" ? "viewer" : "manager";
        if (this.members().filter((x) => x.active).length >= this.limits().teamMembers) {
          throw new HttpError(402, "team_limit", `Your plan includes ${this.limits().teamMembers} team member${this.limits().teamMembers === 1 ? "" : "s"}. Upgrade to invite more.`);
        }
        const code = newId("inv", 10).slice(4).toUpperCase();
        const res = await callDO(this.env, "Invite", code, "/create", { body: { propertyId: this.ctx.id.name, role: r, propertyName: this.profile().name, createdBy: m.accountId } });
        if (!res.ok) throw new HttpError(502, "invite_failed", "Couldn't create the invitation.");
        this.audit(m.accountId, "team.invite", { role: r });
        return json({ code, role: r, expiresInDays: 7 });
      }
      const teamMatch = path.match(/^\/team\/(acc_[a-z0-9]+)$/);
      if (teamMatch && method === "DELETE") {
        const m = this.requireRole(accountId, "owner");
        if (teamMatch[1] === m.accountId) throw new HttpError(400, "cannot_remove_owner", "The owner can't be removed.");
        this.sql.exec(`DELETE FROM members WHERE account_id = ? AND role != 'owner'`, teamMatch[1]);
        await callDO(this.env, "Account", teamMatch[1], "/remove-property", { body: { propertyId: this.ctx.id.name } });
        this.audit(m.accountId, "team.remove", { accountId: teamMatch[1] });
        return json({ ok: true });
      }
      if (path === "/team/active" && method === "POST") {
        const m = this.requireRole(accountId, "owner");
        const { ids } = await readJson<{ ids?: string[] }>(request);
        const keep = new Set([m.accountId, ...(Array.isArray(ids) ? ids : [])]);
        const limit = this.limits().teamMembers;
        if (keep.size > limit) throw new HttpError(400, "team_limit", `Choose up to ${limit} people, including you.`);
        for (const mem of this.members()) this.sql.exec(`UPDATE members SET active = ? WHERE account_id = ?`, keep.has(mem.accountId) ? 1 : 0, mem.accountId);
        this.audit(m.accountId, "team.active", { ids: [...keep] });
        return json({ members: this.members() });
      }

      /* Billing */
      if (path === "/billing/sync" && method === "POST") {
        const m = this.requireRole(accountId, "viewer");
        const snap = await this.syncBilling();
        this.audit(m.accountId, "billing.sync", { plan: snap?.plan ?? "none", state: snap?.state ?? "none" });
        return json(this.overview(m.accountId));
      }
      if (path === "/usage" && method === "GET") {
        this.requireRole(accountId, "viewer");
        const ps = this.planState();
        const u = this.usage();
        return json({ month: monthKey(), orevAnswersUsed: u.orevAnswers, orevAnswersAllowed: orevAllowance(ps.plan, ps.state), budgetReached: u.costUsd >= PLANS[ps.plan].limits.monthlyCostCeilingUsd });
      }
      if (path === "/audit" && method === "GET") {
        this.requireRole(accountId, "owner");
        const rows = this.sql.exec<{ at: number; account_id: string | null; action: string; detail: string | null }>(`SELECT at, account_id, action, detail FROM audit ORDER BY id DESC LIMIT 200`).toArray();
        return json({ items: rows.map((r) => ({ at: r.at, accountId: r.account_id, action: r.action, detail: r.detail ? JSON.parse(r.detail) : null })) });
      }
      if (path === "/export" && method === "GET") {
        this.requireRole(accountId, "owner");
        return json({
          exportedAt: new Date().toISOString(),
          profile: this.profile(),
          performance: this.performanceRows("0000-01-01", "9999-12-31"),
          snapshots: this.snapshotRows(),
          competitors: this.competitors(),
          events: this.eventRows("0000-01-01", "9999-12-31"),
        });
      }

      throw new HttpError(404, "not_found", "Unknown property route.");
    } catch (e) {
      return errorResponse(e);
    }
  }

  /* ---------------------------------------------------------------- */
  /* Internal routes (Worker/DO only)                                 */
  /* ---------------------------------------------------------------- */

  private async internal(path: string, request: Request): Promise<Response> {
    if (path === "/internal/init") {
      const body = await readJson<{ ownerId: string; ownerName: string | null; ownerEmail: string | null; profile: Partial<Profile> }>(request);
      if (this.meta("profile")) throw new HttpError(409, "exists", "Property already exists.");
      const now = Date.now();
      const tz = isValidTimeZone(body.profile.timeZone) ? body.profile.timeZone : "UTC";
      const profile: Profile = {
        id: this.ctx.id.name ?? "",
        name: clampString(body.profile.name, 160) ?? "My property",
        address: clampString(body.profile.address, 300),
        city: clampString(body.profile.city, 100),
        region: clampString(body.profile.region, 100),
        country: clampString(body.profile.country, 100),
        countryCode: clampString(body.profile.countryCode, 3),
        latitude: finiteNumber(body.profile.latitude),
        longitude: finiteNumber(body.profile.longitude),
        timeZone: tz,
        currency: typeof body.profile.currency === "string" && CURRENCY.test(body.profile.currency) ? body.profile.currency : "USD",
        roomCount: null,
        website: null,
        phone: clampString(body.profile.phone, 40),
        starRating: null,
        propertyType: null,
        amenities: [],
        description: null,
        goals: [],
        xoteloKey: null,
        xoteloName: null,
        setupStep: "website",
        setupCompleted: false,
        fieldSources: { name: { source: body.profile.latitude ? "maps" : "user", confirmedAt: now } },
        createdAt: now,
        updatedAt: now,
      };
      if (typeof body.profile.website === "string") {
        try {
          profile.website = validatePublicUrl(body.profile.website).toString();
        } catch {
          profile.website = null;
        }
      }
      this.saveProfile(profile);
      this.sql.exec(`INSERT INTO members (account_id, role, name, email, added_at, active) VALUES (?, 'owner', ?, ?, ?, 1)`, body.ownerId, body.ownerName, body.ownerEmail, now);
      this.audit(body.ownerId, "property.create", { name: profile.name });
      return json(profile, 201);
    }
    if (path === "/internal/join") {
      const body = await readJson<{ accountId: string; role: Role; name: string | null; email: string | null }>(request);
      const existing = this.members().find((m) => m.accountId === body.accountId);
      if (existing) return json({ ok: true, name: this.profile().name, already: true });
      if (this.members().filter((m) => m.active).length >= this.limits().teamMembers) throw new HttpError(402, "team_limit", "This property's team is full on its current plan.");
      this.sql.exec(`INSERT INTO members (account_id, role, name, email, added_at, active) VALUES (?, ?, ?, ?, ?, 1)`, body.accountId, body.role === "viewer" ? "viewer" : "manager", body.name, body.email, Date.now());
      this.audit(body.accountId, "team.join", { role: body.role });
      return json({ ok: true, name: this.profile().name });
    }
    if (path === "/internal/remove-member") {
      const { accountId } = await readJson<{ accountId: string }>(request);
      this.sql.exec(`DELETE FROM members WHERE account_id = ? AND role != 'owner'`, accountId);
      return json({ ok: true });
    }
    if (path === "/internal/destroy") return json(await this.destroy());
    if (path === "/internal/billing-sync") {
      const snap = await this.syncBilling();
      return json({ plan: snap?.plan ?? "none", state: snap?.state ?? "none" });
    }
    throw new HttpError(404, "not_found", "Unknown internal route.");
  }

  private async destroy() {
    if (!this.meta("profile")) return { ok: true };
    const id = this.ctx.id.name ?? "";
    for (const m of this.members()) {
      await callDO(this.env, "Account", m.accountId, "/remove-property", { body: { propertyId: id } }).catch(() => null);
    }
    try {
      await this.env.DO.deleteAlarm("Property", id);
    } catch {
      // no alarm set
    }
    await this.ctx.storage.deleteAll();
    return { ok: true };
  }

  /* ---------------------------------------------------------------- */
  /* Profile                                                          */
  /* ---------------------------------------------------------------- */

  private updateProfile(accountId: string, body: Record<string, unknown>) {
    const p = this.profile();
    const sources = (body.fieldSources ?? {}) as Record<string, FieldSource>;
    const changed: string[] = [];
    const set = <K extends keyof Profile>(key: K, value: Profile[K]) => {
      if (JSON.stringify(p[key]) !== JSON.stringify(value)) {
        p[key] = value;
        changed.push(key);
        const src = sources[key];
        p.fieldSources[key] = {
          source: src?.source === "website" || src?.source === "maps" ? src.source : "user",
          confidence: src?.confidence,
          url: typeof src?.url === "string" ? src.url.slice(0, 300) : undefined,
          confirmedAt: Date.now(),
        };
      }
    };
    const str = (k: keyof Profile, max: number) => {
      if (k in body) set(k, clampString(body[k], max) as never);
    };
    if ("name" in body) {
      const n = clampString(body.name, 160);
      if (!n) throw new HttpError(400, "invalid_name", "Property name can't be empty.");
      set("name", n);
    }
    str("address", 300);
    str("city", 100);
    str("region", 100);
    str("country", 100);
    str("countryCode", 3);
    str("phone", 40);
    str("propertyType", 60);
    str("description", 400);
    if ("latitude" in body) set("latitude", finiteNumber(body.latitude));
    if ("longitude" in body) set("longitude", finiteNumber(body.longitude));
    if ("website" in body) {
      if (body.website === null || body.website === "") set("website", null);
      else set("website", validatePublicUrl(String(body.website)).toString());
    }
    if ("roomCount" in body) {
      const n = body.roomCount;
      if (n === null) set("roomCount", null);
      else if (typeof n !== "number" || !Number.isInteger(n) || n < 1 || n > 10_000) throw new HttpError(400, "invalid_rooms", "Room count must be a whole number between 1 and 10,000.");
      else set("roomCount", n);
    }
    if ("starRating" in body) {
      const n = body.starRating;
      if (n === null) set("starRating", null);
      else if (typeof n !== "number" || n < 1 || n > 7) throw new HttpError(400, "invalid_stars", "Star rating must be between 1 and 7.");
      else set("starRating", n);
    }
    if ("timeZone" in body) {
      if (!isValidTimeZone(body.timeZone)) throw new HttpError(400, "invalid_timezone", "That time zone isn't recognized.");
      set("timeZone", body.timeZone);
    }
    if ("currency" in body) {
      const c = String(body.currency ?? "").toUpperCase();
      if (!CURRENCY.test(c)) throw new HttpError(400, "invalid_currency", "Currency must be a 3-letter ISO code.");
      if (c !== p.currency) this.sql.exec(`DELETE FROM rate_latest WHERE manual = 0`);
      set("currency", c);
    }
    if ("amenities" in body && Array.isArray(body.amenities)) {
      set("amenities", body.amenities.map((a) => clampString(a, 60)).filter((a): a is string => !!a).slice(0, 30));
    }
    if ("goals" in body && Array.isArray(body.goals)) {
      set("goals", body.goals.filter((g): g is string => typeof g === "string" && GOALS.includes(g)).slice(0, 4));
    }
    if (changed.length) {
      this.saveProfile(p);
      this.audit(accountId, "profile.update", { fields: changed });
      this.bumpData();
      if (changed.includes("name")) {
        for (const m of this.members()) {
          this.ctx.waitUntil(callDO(this.env, "Account", m.accountId, "/rename-property", { body: { propertyId: p.id, name: p.name } }).then(() => undefined).catch(() => undefined));
        }
      }
    }
    return p;
  }

  /* ---------------------------------------------------------------- */
  /* Hotel matching & competitors                                     */
  /* ---------------------------------------------------------------- */

  private async match(force: boolean): Promise<MatchResult & { cachedAt: number }> {
    const cached = this.metaJson<MatchResult & { cachedAt: number }>("match_cache");
    if (!force && cached && Date.now() - cached.cachedAt < 86_400_000) return cached;
    this.assertBudget("Hotel matching");
    const p = this.profile();
    const result = await matchHotel(this.env, { name: p.name, city: p.city, latitude: p.latitude, longitude: p.longitude });
    this.meter("hotel_match", 1, result.costUsd);
    const payload = { ...result, cachedAt: Date.now() };
    this.setMeta("match_cache", JSON.stringify(payload));
    return payload;
  }

  private addCompetitor(accountId: string, body: Record<string, unknown>) {
    const name = clampString(body.name, 160);
    if (!name) throw new HttpError(400, "invalid_name", "Competitor name is required.");
    const key = typeof body.xoteloKey === "string" && /^g\d+-d\d+$/.test(body.xoteloKey) ? body.xoteloKey : null;
    const comps = this.competitors();
    if (key && (comps.some((c) => c.xoteloKey === key) || this.profile().xoteloKey === key)) throw new HttpError(409, "duplicate", "That hotel is already tracked.");
    if (comps.some((c) => c.name.toLowerCase() === name.toLowerCase())) throw new HttpError(409, "duplicate", "A competitor with that name is already tracked.");
    const limit = this.limits().competitors;
    const activeCount = comps.filter((c) => c.active).length;
    if (comps.length >= 20) throw new HttpError(400, "competitor_list_full", "You can save up to 20 hotels. Remove one first.");
    // Over-limit picks are saved as inactive (not refreshed) so an upgrade can switch them on.
    const isActive = activeCount < limit;
    const c: Competitor = {
      id: newId("cmp", 12),
      name,
      xoteloKey: key,
      latitude: finiteNumber(body.latitude),
      longitude: finiteNumber(body.longitude),
      distanceKm: finiteNumber(body.distanceKm),
      rating: finiteNumber(body.rating),
      priority: comps.length,
      active: isActive,
      addedAt: Date.now(),
    };
    this.sql.exec(
      `INSERT INTO competitors (id, name, xotelo_key, latitude, longitude, distance_km, rating, priority, active, added_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      c.id,
      c.name,
      c.xoteloKey,
      c.latitude,
      c.longitude,
      c.distanceKm,
      c.rating,
      c.priority,
      isActive ? 1 : 0,
      c.addedAt,
    );
    this.audit(accountId, "competitor.add", { id: c.id, name: c.name, active: isActive });
    this.bumpData();
    return c;
  }

  private setActiveCompetitors(accountId: string, ids: string[]) {
    const limit = this.limits().competitors;
    const keep = new Set(ids);
    if (keep.size > limit) throw new HttpError(400, "competitor_limit", `Choose up to ${limit} competitor${limit === 1 ? "" : "s"}.`);
    for (const c of this.competitors()) this.sql.exec(`UPDATE competitors SET active = ? WHERE id = ?`, keep.has(c.id) ? 1 : 0, c.id);
    this.audit(accountId, "competitor.active", { ids });
    this.bumpData();
    return { competitors: this.competitors(), limit };
  }

  /**
   * Re-applies plan limits after a plan change. Downgrades keep the first N competitors
   * (by priority) active — the owner can then pick which ones via /competitors/active.
   * Upgrades switch saved competitors back on, in priority order, up to the new limit.
   */
  private enforceLimits(): void {
    const limits = this.limits();
    const comps = this.competitors();
    const active = comps.filter((c) => c.active);
    if (active.length > limits.competitors) {
      for (const c of active.slice(limits.competitors)) this.sql.exec(`UPDATE competitors SET active = 0 WHERE id = ?`, c.id);
    } else if (active.length < limits.competitors) {
      const room = limits.competitors - active.length;
      for (const c of comps.filter((x) => !x.active).slice(0, room)) this.sql.exec(`UPDATE competitors SET active = 1 WHERE id = ?`, c.id);
    }
    const members = this.members().filter((m) => m.active);
    if (members.length > limits.teamMembers) {
      const others = members.filter((m) => m.role !== "owner");
      for (const m of others.slice(Math.max(0, limits.teamMembers - 1))) this.sql.exec(`UPDATE members SET active = 0 WHERE account_id = ?`, m.accountId);
    }
  }

  /* ---------------------------------------------------------------- */
  /* Performance data                                                 */
  /* ---------------------------------------------------------------- */

  private upsertPerformance(row: { date: string; kind: DataKind; roomsAvailable: number; roomsSold: number; roomRevenue: number | null }, source: string): void {
    const now = Date.now();
    this.sql.exec(
      `INSERT INTO performance (date, kind, rooms_available, rooms_sold, room_revenue, source, captured_at) VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(date, kind) DO UPDATE SET rooms_available = excluded.rooms_available, rooms_sold = excluded.rooms_sold, room_revenue = excluded.room_revenue, source = excluded.source, captured_at = excluded.captured_at`,
      row.date,
      row.kind,
      row.roomsAvailable,
      row.roomsSold,
      row.roomRevenue,
      source,
      now,
    );
    if (row.kind === "on_the_books") {
      const asOf = this.today();
      this.sql.exec(
        `INSERT INTO otb_snapshots (as_of, stay_date, rooms_sold, room_revenue, source) VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(as_of, stay_date) DO UPDATE SET rooms_sold = excluded.rooms_sold, room_revenue = excluded.room_revenue, source = excluded.source`,
        asOf,
        row.date,
        row.roomsSold,
        row.roomRevenue,
        source,
      );
    }
  }

  private writePerformance(accountId: string, body: { rows?: unknown[] }) {
    const rows = Array.isArray(body.rows) ? body.rows.slice(0, 400) : [];
    const today = this.today();
    const accepted: string[] = [];
    const issues: { row: number; field: string; message: string }[] = [];
    rows.forEach((raw, i) => {
      const r = raw as Record<string, unknown>;
      const date = r.date;
      if (!isIsoDate(date)) {
        issues.push({ row: i + 1, field: "date", message: "Date must be YYYY-MM-DD." });
        return;
      }
      const kind: DataKind = date < today ? "actual" : "on_the_books";
      const candidate = {
        date,
        kind,
        roomsAvailable: typeof r.roomsAvailable === "number" ? r.roomsAvailable : this.profile().roomCount ?? NaN,
        roomsSold: r.roomsSold as number,
        roomRevenue: r.roomRevenue === null || r.roomRevenue === undefined ? null : (r.roomRevenue as number),
      };
      const rowIssues = validateDaily(candidate, i + 1);
      if (rowIssues.length) {
        issues.push(...rowIssues);
        return;
      }
      this.upsertPerformance(candidate, "manual");
      accepted.push(date);
    });
    if (accepted.length) {
      this.audit(accountId, "performance.manual", { dates: accepted.slice(0, 31) });
      this.bumpData();
    }
    return { accepted: accepted.length, issues };
  }

  private importCsv(accountId: string, body: { csv?: string; kind?: string; commit?: boolean; fileName?: string }) {
    const csv = typeof body.csv === "string" ? body.csv : "";
    if (!csv.trim()) throw new HttpError(400, "empty_file", "The file is empty.");
    const today = this.today();
    const forced: DataKind | null = body.kind === "actual" || body.kind === "on_the_books" ? body.kind : null;
    const result = importPerformanceCsv(csv, this.profile().roomCount, forced ?? "actual");
    const rows = result.rows.map((r) => ({ ...r, kind: (forced ?? (r.date < today ? "actual" : "on_the_books")) as DataKind }));
    const preview = {
      totalLines: result.totalLines,
      validRows: rows.length,
      issues: result.issues.slice(0, 50),
      issueCount: result.issues.length,
      columns: result.columns,
      range: rows.length ? { start: rows[0].date, end: rows[rows.length - 1].date } : null,
      actualDays: rows.filter((r) => r.kind === "actual").length,
      onTheBooksDays: rows.filter((r) => r.kind === "on_the_books").length,
      sample: rows.slice(0, 5),
      committed: false,
    };
    if (!body.commit) return preview;
    if (!rows.length) throw new HttpError(400, "nothing_to_import", "There are no valid rows to import.");
    for (const r of rows) {
      if (r.asOf && r.kind === "on_the_books") {
        this.sql.exec(
          `INSERT INTO otb_snapshots (as_of, stay_date, rooms_sold, room_revenue, source) VALUES (?, ?, ?, ?, 'csv') ON CONFLICT(as_of, stay_date) DO UPDATE SET rooms_sold = excluded.rooms_sold, room_revenue = excluded.room_revenue`,
          r.asOf,
          r.date,
          r.roomsSold,
          r.roomRevenue,
        );
      }
      this.upsertPerformance(r, "csv");
    }
    this.sql.exec(`INSERT INTO imports (id, at, account_id, kind, source, rows, issues) VALUES (?, ?, ?, 'performance', ?, ?, ?)`, newId("imp", 10), Date.now(), accountId, clampString(body.fileName, 120) ?? "csv", rows.length, result.issues.length);
    this.audit(accountId, "performance.csv", { rows: rows.length, issues: result.issues.length });
    this.bumpData();
    return { ...preview, committed: true };
  }

  /** Loads clearly-labelled demonstration data. Stored with source = 'sample' and removable. */
  private loadSample(accountId: string) {
    const p = this.profile();
    const rooms = p.roomCount ?? 48;
    const today = this.today();
    let seed = 7;
    const rand = () => {
      seed = (seed * 16807) % 2147483647;
      return seed / 2147483647;
    };
    for (let i = -56; i <= 45; i++) {
      const date = addDays(today, i);
      const dow = new Date(`${date}T12:00:00Z`).getUTCDay();
      const weekend = dow === 5 || dow === 6;
      const base = weekend ? 0.86 : dow === 0 ? 0.58 : 0.7;
      let occ = Math.min(0.98, Math.max(0.3, base + (rand() - 0.5) * 0.14));
      if (i >= 0) occ *= Math.max(0.35, 1 - i / 60);
      const sold = Math.round(rooms * occ);
      const adrValue = (weekend ? 189 : 152) * (1 + (rand() - 0.5) * 0.1);
      const exists = this.sql.exec<{ n: number }>(`SELECT COUNT(*) AS n FROM performance WHERE date = ? AND source != 'sample'`, date).one().n;
      if (exists) continue;
      this.upsertPerformance({ date, kind: i < 0 ? "actual" : "on_the_books", roomsAvailable: rooms, roomsSold: sold, roomRevenue: Math.round(sold * adrValue * 100) / 100 }, "sample");
      if (i >= 0) {
        const earlier = Math.max(0, sold - Math.round(rooms * (0.04 + rand() * 0.06)));
        this.sql.exec(
          `INSERT INTO otb_snapshots (as_of, stay_date, rooms_sold, room_revenue, source) VALUES (?, ?, ?, NULL, 'sample') ON CONFLICT(as_of, stay_date) DO NOTHING`,
          addDays(today, -7),
          date,
          earlier,
        );
      }
    }
    this.audit(accountId, "sample.load");
    this.bumpData();
    return { ok: true };
  }

  /* ---------------------------------------------------------------- */
  /* Rates                                                            */
  /* ---------------------------------------------------------------- */

  private refreshInfo() {
    const limit = this.limits().rateRefreshesPerDay;
    const used = Number(this.meta(`rate_refreshes:${this.today()}`) ?? "0");
    const queue = this.metaJson<unknown[]>("rate_queue") ?? [];
    return { perDay: limit, usedToday: used, remainingToday: Math.max(0, limit - used), inProgress: queue.length > 0, pending: queue.length };
  }

  private buildRateQueue(): number {
    const p = this.profile();
    const horizon = this.limits().rateHorizonDays;
    const dates = sampleStayDates(this.today(), horizon);
    const hotels: { ref: string; key: string }[] = [];
    if (p.xoteloKey) hotels.push({ ref: "own", key: p.xoteloKey });
    for (const c of this.competitors()) if (c.active && c.xoteloKey) hotels.push({ ref: c.id, key: c.xoteloKey });
    const queue: { ref: string; key: string; date: string }[] = [];
    for (const d of dates) for (const h of hotels) queue.push({ ...h, date: d });
    this.setMeta("rate_queue", JSON.stringify(queue));
    return queue.length;
  }

  /** Processes up to `max` queued rate lookups. Returns remaining count. */
  private async processRateQueue(max = 36): Promise<number> {
    const queue = this.metaJson<{ ref: string; key: string; date: string }[]>("rate_queue") ?? [];
    if (!queue.length) return 0;
    const batch = queue.slice(0, max);
    const rest = queue.slice(max);
    const currency = this.profile().currency;
    const now = Date.now();
    const results = await mapLimit(batch, 6, async (t) => ({ t, rates: await fetchRates(t.key, t.date, addDays(t.date, 1), currency) }));
    let found = 0;
    for (const { t, rates } of results) {
      if (!rates || !rates.length) continue;
      const lowest = rates.reduce((a, b) => (b.rate < a.rate ? b : a));
      found++;
      this.sql.exec(`INSERT INTO rate_history (hotel_ref, stay_date, rate, channel, currency, observed_at, manual) VALUES (?, ?, ?, ?, ?, ?, 0)`, t.ref, t.date, lowest.rate, lowest.name, currency, now);
      this.sql.exec(
        `INSERT INTO rate_latest (hotel_ref, stay_date, rate, channel, currency, observed_at, manual) VALUES (?, ?, ?, ?, ?, ?, 0)
         ON CONFLICT(hotel_ref, stay_date) DO UPDATE SET rate = excluded.rate, channel = excluded.channel, currency = excluded.currency, observed_at = excluded.observed_at, manual = 0`,
        t.ref,
        t.date,
        lowest.rate,
        lowest.name,
        currency,
        now,
      );
    }
    this.setMeta("rate_queue", JSON.stringify(rest));
    if (!rest.length) {
      this.setMeta("rates_last_refresh", String(now));
      this.sql.exec(`DELETE FROM rate_history WHERE observed_at < ?`, now - 120 * 86_400_000);
      this.sql.exec(`DELETE FROM rate_latest WHERE stay_date < ?`, addDays(this.today(), -2));
    }
    if (found) this.bumpData();
    return rest.length;
  }

  private async manualRefresh(accountId: string) {
    const info = this.refreshInfo();
    if (info.inProgress) {
      await this.processRateQueue();
      return { ...this.refreshInfo(), started: false };
    }
    if (info.remainingToday <= 0) {
      throw new HttpError(429, "refresh_limit", `Your plan refreshes rates ${info.perDay}× a day. The next refresh is available tomorrow.`, info);
    }
    const total = this.buildRateQueue();
    if (!total) throw new HttpError(400, "nothing_to_refresh", "Confirm your own listing or add competitors with a public listing first.");
    this.setMeta(`rate_refreshes:${this.today()}`, String(info.usedToday + 1));
    this.audit(accountId, "rates.refresh", { lookups: total });
    const remaining = await this.processRateQueue();
    if (remaining > 0) await this.env.DO.setAlarm("Property", this.ctx.id.name ?? "", Date.now() + 15_000);
    return { ...this.refreshInfo(), started: true, total };
  }

  private manualRate(accountId: string, body: { hotel?: string; stayDate?: string; rate?: number | null }) {
    const hotel = body.hotel === "own" ? "own" : this.competitors().find((c) => c.id === body.hotel)?.id;
    if (!hotel) throw new HttpError(400, "invalid_hotel", "Choose your property or a tracked competitor.");
    if (!isIsoDate(body.stayDate)) throw new HttpError(400, "invalid_date", "Choose a valid stay date.");
    if (body.rate === null) {
      this.sql.exec(`DELETE FROM rate_latest WHERE hotel_ref = ? AND stay_date = ? AND manual = 1`, hotel, body.stayDate);
    } else {
      if (typeof body.rate !== "number" || !Number.isFinite(body.rate) || body.rate <= 0 || body.rate > 100_000) throw new HttpError(400, "invalid_rate", "Enter a rate above 0.");
      const now = Date.now();
      const cur = this.profile().currency;
      this.sql.exec(
        `INSERT INTO rate_latest (hotel_ref, stay_date, rate, channel, currency, observed_at, manual) VALUES (?, ?, ?, 'Manual entry', ?, ?, 1)
         ON CONFLICT(hotel_ref, stay_date) DO UPDATE SET rate = excluded.rate, channel = excluded.channel, currency = excluded.currency, observed_at = excluded.observed_at, manual = 1`,
        hotel,
        body.stayDate,
        body.rate,
        cur,
        now,
      );
      this.sql.exec(`INSERT INTO rate_history (hotel_ref, stay_date, rate, channel, currency, observed_at, manual) VALUES (?, ?, ?, 'Manual entry', ?, ?, 1)`, hotel, body.stayDate, body.rate, cur, now);
    }
    this.audit(accountId, "rates.manual", { hotel, stayDate: body.stayDate });
    this.bumpData();
    return { ok: true };
  }

  /* ---------------------------------------------------------------- */
  /* Events                                                           */
  /* ---------------------------------------------------------------- */

  private async discover(accountId: string | null, manual: boolean) {
    const p = this.profile();
    if (!p.city) throw new HttpError(400, "missing_city", "Add your property's city to discover local events.");
    const last = Number(this.meta("events_last_discovery") ?? "0");
    const horizonDays = this.limits().eventHorizonDays;
    const lastHorizon = Number(this.meta("events_last_horizon") ?? "0");
    if (manual && Date.now() - last < 6 * 3_600_000 && lastHorizon >= horizonDays) {
      return { added: 0, skipped: true, message: "Events were checked in the last few hours.", lastDiscoveryAt: last };
    }
    this.assertBudget("Event discovery");
    const today = this.today();
    const end = addDays(today, horizonDays);
    let discovered: Awaited<ReturnType<typeof discoverEvents>>;
    try {
      discovered = await discoverEvents(this.env, { city: p.city, region: p.region, country: p.country, start: today, end });
    } catch (e) {
      if (e instanceof HttpError) throw e;
      console.warn("event discovery failed", e instanceof Error ? e.message : String(e));
      throw new HttpError(502, "events_unavailable", "Event search isn't available right now. Please try again shortly.");
    }
    const { events, costUsd } = discovered;
    this.meter("event_discovery", 1, costUsd);
    let added = 0;
    for (const e of events) {
      const key = `${normalizeTitle(e.title)}|${e.startDate}`;
      const dup = this.sql.exec<{ n: number }>(`SELECT COUNT(*) AS n FROM events WHERE dedupe_key = ? OR (dedupe_key LIKE ? AND ABS(julianday(start_date) - julianday(?)) <= 2)`, key, `${normalizeTitle(e.title)}|%`, e.startDate).one().n;
      if (dup) continue;
      this.sql.exec(
        `INSERT INTO events (id, title, start_date, end_date, venue, category, source_url, source_title, expected_attendance, source_reachable, status, origin, dedupe_key, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'unverified', 'discovered', ?, ?)`,
        newId("evt", 12),
        e.title,
        e.startDate,
        e.endDate,
        e.venue,
        e.category,
        e.sourceUrl,
        e.sourceTitle,
        e.expectedAttendance,
        e.sourceReachable ? 1 : 0,
        key,
        Date.now(),
      );
      added++;
    }
    this.setMeta("events_last_discovery", String(Date.now()));
    this.setMeta("events_last_horizon", String(horizonDays));
    this.audit(accountId, "events.discover", { found: events.length, added });
    if (added) this.bumpData();
    return { added, found: events.length, skipped: false, lastDiscoveryAt: Date.now() };
  }

  private addEvent(accountId: string, body: Record<string, unknown>) {
    const title = clampString(body.title, 140);
    if (!title) throw new HttpError(400, "invalid_title", "Event name is required.");
    if (!isIsoDate(body.startDate)) throw new HttpError(400, "invalid_date", "Choose a start date.");
    const end = isIsoDate(body.endDate) && body.endDate >= body.startDate ? body.endDate : body.startDate;
    let sourceUrl: string | null = null;
    if (typeof body.sourceUrl === "string" && body.sourceUrl.trim()) sourceUrl = validatePublicUrl(body.sourceUrl).toString();
    const id = newId("evt", 12);
    const category = typeof body.category === "string" ? body.category.slice(0, 30) : "other";
    this.sql.exec(
      `INSERT INTO events (id, title, start_date, end_date, venue, category, source_url, source_title, expected_attendance, source_reachable, status, origin, dedupe_key, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, NULL, ?, 0, 'confirmed', 'manual', ?, ?)`,
      id,
      title,
      body.startDate,
      end,
      clampString(body.venue, 140),
      category,
      sourceUrl,
      typeof body.expectedAttendance === "number" && body.expectedAttendance > 0 ? Math.round(body.expectedAttendance) : null,
      `${normalizeTitle(title)}|${body.startDate}`,
      Date.now(),
    );
    this.audit(accountId, "event.add", { id, title });
    this.bumpData();
    return this.eventRows(body.startDate, end).find((e) => e.id === id);
  }

  /* ---------------------------------------------------------------- */
  /* Orev                                                             */
  /* ---------------------------------------------------------------- */

  private async briefing(force: boolean): Promise<Briefing> {
    const version = this.meta("data_version") ?? "0";
    const today = this.today();
    const cached = this.metaJson<Briefing & { dataVersion: string }>("briefing");
    if (!force && cached && cached.date === today && cached.dataVersion === version) return cached;
    const built = buildBriefing(this.reader());
    const { templateSummary, ...rest } = built;
    let summary = templateSummary;
    let summarySource: Briefing["summarySource"] = "template";
    const ps = this.planState();
    const canNarrate = ps.plan !== "none" && this.usage().costUsd < PLANS[ps.plan].limits.monthlyCostCeilingUsd && built.headline.length > 0;
    if (canNarrate) {
      const facts = [
        ...built.headline.map((h) => `${h.label} (${h.period}, ${h.basis}): ${h.formatted}`),
        ...built.insights.map((i) => `${i.title}. ${i.detail}`),
        ...built.dataGaps.map((g) => `Gap: ${g}`),
      ].join("\n");
      const n = await narrate(this.env, facts, templateSummary);
      if (n) {
        this.meter("briefing", 1, n.costUsd);
        summary = n.text;
        summarySource = n.text === templateSummary ? "template" : "orev";
      }
    }
    const b: Briefing = { ...rest, summary, summarySource };
    this.setMeta("briefing", JSON.stringify({ ...b, dataVersion: version }));
    return b;
  }

  private async ask(accountId: string, body: { question?: string; history?: AskTurn[] }) {
    const question = clampString(body.question, 1500);
    if (!question) throw new HttpError(400, "empty_question", "Ask Orev a question.");
    const ps = this.planState();
    const allowed = orevAllowance(ps.plan, ps.state);
    const used = this.usage().orevAnswers;
    if (used >= allowed) {
      throw new HttpError(402, "orev_limit", ps.plan === "none" ? "Start your free trial to keep asking Orev." : `You've used all ${allowed} Orev answers for this ${ps.state === "trial" ? "trial" : "month"}. Your direct data views still work.`, { used, allowed });
    }
    this.assertBudget("Ask Orev");
    const history = Array.isArray(body.history) ? body.history.filter((t) => t && (t.role === "user" || t.role === "orev") && typeof t.text === "string") : [];
    const result = await askOrev(this.env, this.reader(), question, history);
    this.meter("orev_answers", 1, result.costUsd);
    const id = newId("ask", 12);
    this.sql.exec(
      `INSERT INTO ask_log (id, account_id, question, answer, mood, evidence, follow_ups, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      id,
      accountId,
      question,
      result.answer,
      result.mood,
      JSON.stringify(result.evidence),
      JSON.stringify(result.followUps),
      Date.now(),
    );
    this.sql.exec(`DELETE FROM ask_log WHERE id NOT IN (SELECT id FROM ask_log ORDER BY created_at DESC LIMIT 300)`);
    return { id, answer: result.answer, mood: result.mood, evidence: result.evidence, followUps: result.followUps, usage: { used: used + 1, allowed } };
  }

  /* ---------------------------------------------------------------- */
  /* Billing                                                          */
  /* ---------------------------------------------------------------- */

  private async syncBilling(): Promise<BillingSnapshot | null> {
    const id = this.ctx.id.name ?? "";
    const snap = await fetchSubscriber(this.env, id);
    if (!snap) return this.billing();
    const prev = this.billing();
    if (prev?.trialUsed) snap.trialUsed = true;
    this.setMeta("billing", JSON.stringify(snap));
    if (prev?.plan !== snap.plan || prev?.state !== snap.state) {
      this.audit(null, "billing.change", { from: prev ? `${prev.plan}/${prev.state}` : "none", to: `${snap.plan}/${snap.state}` });
      this.enforceLimits();
      this.bumpData();
      await this.scheduleNext();
    }
    return snap;
  }

  /* ---------------------------------------------------------------- */
  /* Scheduling                                                       */
  /* ---------------------------------------------------------------- */

  private async scheduleNext(): Promise<void> {
    const id = this.ctx.id.name;
    if (!id || !this.meta("profile")) return;
    const ps = this.planState();
    if (ps.plan === "none") return;
    const limits = PLANS[ps.plan].limits;
    const interval = 86_400_000 / limits.rateRefreshesPerDay;
    const lastRates = Number(this.meta("rates_last_refresh") ?? "0");
    const lastEvents = Number(this.meta("events_last_discovery") ?? "0");
    const horizonGrew = Number(this.meta("events_last_horizon") ?? "0") < limits.eventHorizonDays;
    const nextEvents = horizonGrew ? Date.now() : lastEvents + 7 * 86_400_000;
    const next = Math.max(Date.now() + 60_000, Math.min(lastRates + interval, nextEvents));
    await this.env.DO.setAlarm("Property", id, next);
  }

  /** Scheduled refresh: public rates per plan cadence, events weekly. Idempotent. */
  async onAlarm(): Promise<void> {
    if (!this.meta("profile")) return;
    const id = this.ctx.id.name ?? "";
    const remaining = await this.processRateQueue();
    if (remaining > 0) {
      await this.env.DO.setAlarm("Property", id, Date.now() + 20_000);
      return;
    }
    const ps = this.planState();
    if (ps.plan === "none") return;
    const limits = PLANS[ps.plan].limits;
    const interval = 86_400_000 / limits.rateRefreshesPerDay;
    const lastRates = Number(this.meta("rates_last_refresh") ?? "0");
    if (Date.now() - lastRates >= interval - 60_000) {
      const used = Number(this.meta(`rate_refreshes:${this.today()}`) ?? "0");
      if (used < limits.rateRefreshesPerDay && this.buildRateQueue() > 0) {
        this.setMeta(`rate_refreshes:${this.today()}`, String(used + 1));
        const left = await this.processRateQueue();
        if (left > 0) {
          await this.env.DO.setAlarm("Property", id, Date.now() + 20_000);
          return;
        }
      } else {
        this.setMeta("rates_last_refresh", String(Date.now()));
      }
    }
    const lastEvents = Number(this.meta("events_last_discovery") ?? "0");
    const horizonGrew = Number(this.meta("events_last_horizon") ?? "0") < limits.eventHorizonDays;
    if ((horizonGrew || Date.now() - lastEvents >= 7 * 86_400_000) && this.profile().city) {
      try {
        await this.discover(null, false);
      } catch (e) {
        console.warn("scheduled event discovery skipped", e instanceof Error ? e.message : String(e));
        this.setMeta("events_last_discovery", String(Date.now() - 6 * 86_400_000));
      }
    }
    await this.scheduleNext();
  }
}
