import { chat, MODELS, parseModelJson, type ChatMessage, type ToolDef } from "./ai";
import type { Env } from "./env";
import { aggregate, pace, type PeriodMetrics } from "./metrics";
import type { Briefing, Evidence, EventRow, HeadlineMetric, Insight, MarketSummary, PropertyReader } from "./types";
import { addDays, hourIn, isIsoDate, newId, round } from "./util";

/* ------------------------------------------------------------------ */
/* Formatting                                                          */
/* ------------------------------------------------------------------ */

export function money(value: number | null, currency: string): string {
  if (value === null) return "—";
  try {
    return new Intl.NumberFormat("en-US", { style: "currency", currency, maximumFractionDigits: value >= 1000 ? 0 : 2 }).format(value);
  } catch {
    return `${currency} ${value.toFixed(2)}`;
  }
}

export function pct(value: number | null, digits = 0): string {
  if (value === null) return "—";
  return `${(value * 100).toFixed(digits)}%`;
}

function basisOf(m: PeriodMetrics): Evidence["basis"] {
  if (m.sampleDays > 0 && m.sampleDays === m.daysWithData) return "sample";
  if (m.kind === "on_the_books") return "on_the_books";
  if (m.kind === "forecast") return "forecast";
  return "actual";
}

/* ------------------------------------------------------------------ */
/* Deterministic briefing                                              */
/* ------------------------------------------------------------------ */

/**
 * Builds today's briefing from stored data only. Every number comes from deterministic
 * calculation; Orev's LLM layer may only rephrase the summary, never add numbers.
 */
export function buildBriefing(r: PropertyReader): Omit<Briefing, "summary" | "summarySource"> & { templateSummary: string } {
  const p = r.profile();
  const today = r.today();
  const cur = p.currency;
  const yesterday = addDays(today, -1);
  const last7Start = addDays(today, -7);
  const prior7Start = addDays(today, -14);
  const perf = r.performance(addDays(today, -60), addDays(today, 90));
  const actuals = perf.filter((x) => x.kind === "actual");
  const otb = perf.filter((x) => x.kind === "on_the_books");
  const hasSampleData = perf.some((x) => x.source === "sample");

  const last7 = aggregate(actuals, last7Start, yesterday, 7);
  const prior7 = aggregate(actuals, prior7Start, addDays(last7Start, -1), 7);
  const next14 = aggregate(otb, today, addDays(today, 13), 14);

  const headline: HeadlineMetric[] = [];
  const insights: Insight[] = [];
  const dataGaps: string[] = [];

  if (last7.daysWithData > 0) {
    const b = basisOf(last7);
    const period = `Last 7 days · ${last7.daysWithData}/7 days of data`;
    headline.push(
      { key: "occupancy", label: "Occupancy", value: last7.occupancy.value, formatted: pct(last7.occupancy.value, 1), basis: b, period, note: last7.occupancy.note },
      { key: "adr", label: "ADR", value: last7.adr.value, formatted: money(last7.adr.value, cur), basis: b, period, note: last7.adr.note },
      { key: "revpar", label: "RevPAR", value: last7.revpar.value, formatted: money(last7.revpar.value, cur), basis: b, period, note: last7.revpar.note },
    );
    if (last7.daysWithData < 7) dataGaps.push(`Only ${last7.daysWithData} of the last 7 days have performance data.`);
    if (prior7.daysWithData >= 5 && last7.daysWithData >= 5 && last7.revpar.value !== null && prior7.revpar.value !== null && prior7.revpar.value > 0) {
      const change = (last7.revpar.value - prior7.revpar.value) / prior7.revpar.value;
      if (Math.abs(change) >= 0.03) {
        insights.push({
          id: newId("ins", 8),
          kind: change > 0 ? "info" : "risk",
          title: change > 0 ? `RevPAR up ${pct(change)} week over week` : `RevPAR down ${pct(Math.abs(change))} week over week`,
          detail: `RevPAR was ${money(last7.revpar.value, cur)} over the last 7 days versus ${money(prior7.revpar.value, cur)} the week before.`,
          evidence: [
            { label: "RevPAR, last 7 days", value: money(last7.revpar.value, cur), basis: b, source: "Your imported performance", asOf: yesterday },
            { label: "RevPAR, prior 7 days", value: money(prior7.revpar.value, cur), basis: basisOf(prior7), source: "Your imported performance", asOf: addDays(last7Start, -1) },
          ],
          labels: [b === "sample" ? "Sample data" : "Actual"],
          action: { label: "Ask Orev why", target: "ask" },
          date: null,
        });
      }
    }
  } else {
    dataGaps.push("No recent performance data yet. Import a report or enter yesterday's numbers to see occupancy, ADR and RevPAR.");
    insights.push({
      id: newId("ins", 8),
      kind: "action",
      title: "Add your recent performance",
      detail: "Orev calculates occupancy, ADR and RevPAR only from your numbers. Nothing is estimated.",
      evidence: [],
      labels: ["Setup"],
      action: { label: "Import data", target: "import" },
      date: null,
    });
  }

  if (next14.daysWithData > 0) {
    headline.push({
      key: "otb_occupancy",
      label: "On the books",
      value: next14.occupancy.value,
      formatted: pct(next14.occupancy.value, 0),
      basis: basisOf(next14) === "sample" ? "sample" : "on_the_books",
      period: `Next 14 days · ${next14.daysWithData}/14 days`,
      note: next14.occupancy.note,
    });
  }

  const pc = pace(r.snapshots(), today, addDays(today, 29));
  if (pc.available && pc.pickupRooms !== null) {
    insights.push({
      id: newId("ins", 8),
      kind: pc.pickupRooms > 0 ? "info" : "risk",
      title: pc.pickupRooms >= 0 ? `Picked up ${pc.pickupRooms} room nights` : `Lost ${Math.abs(pc.pickupRooms)} room nights`,
      detail: `For stays in the next 30 days, on-the-books rooms moved from ${pc.roomsThen} (${pc.comparedTo}) to ${pc.roomsNow} (${pc.asOf}).`,
      evidence: [
        { label: `On the books, ${pc.comparedTo}`, value: String(pc.roomsThen), basis: "on_the_books", source: "Your snapshots", asOf: pc.comparedTo },
        { label: `On the books, ${pc.asOf}`, value: String(pc.roomsNow), basis: "on_the_books", source: "Your snapshots", asOf: pc.asOf },
      ],
      labels: ["Booking pace"],
      action: null,
      date: null,
    });
  } else if (otb.length > 0) {
    dataGaps.push(pc.reason ?? "Booking pace needs two on-the-books snapshots.");
  }

  const market = r.market(today, addDays(today, 13));
  const compsWithData = market.competitors.filter((c) => c.hasData && c.active).length;
  if (market.competitors.length === 0) {
    dataGaps.push("No competitors tracked yet.");
  } else if (compsWithData === 0) {
    dataGaps.push("Public rates for your competitors aren't available yet. You can add rates manually.");
  } else {
    const priced = market.days.filter((d) => d.compMedian !== null);
    const withOwn = priced.filter((d) => d.positionVsMedian !== null);
    for (const d of withOwn) {
      if (d.positionVsMedian! <= -0.15 && d.compCount >= 2) {
        const otbDay = otb.find((o) => o.date === d.stayDate);
        const occ = otbDay ? otbDay.roomsSold / otbDay.roomsAvailable : null;
        insights.push({
          id: newId("ins", 8),
          kind: "opportunity",
          title: `${formatDay(d.stayDate)}: you're ${pct(Math.abs(d.positionVsMedian!))} below the market`,
          detail: `Your lowest public rate is ${money(d.ownLowest, cur)} versus a competitor median of ${money(d.compMedian, cur)} across ${d.compCount} hotels.${occ !== null ? ` You have ${pct(occ)} on the books.` : ""} Worth reviewing — Orev doesn't know your restrictions or room mix.`,
          evidence: [
            { label: "Your lowest public rate", value: money(d.ownLowest, cur), basis: "market", source: market.provider, asOf: d.observedAt ? new Date(d.observedAt).toISOString().slice(0, 10) : null },
            { label: "Competitor median", value: money(d.compMedian, cur), basis: "market", source: market.provider, asOf: d.observedAt ? new Date(d.observedAt).toISOString().slice(0, 10) : null },
            ...(occ !== null ? [{ label: "On the books", value: pct(occ), basis: "on_the_books" as const, source: "Your data", asOf: today }] : []),
          ],
          labels: ["Public rates (Beta)"],
          action: { label: "Open market", target: "market" },
          date: d.stayDate,
        });
        if (insights.filter((i) => i.kind === "opportunity").length >= 2) break;
      }
    }
    if (withOwn.length === 0 && priced.length > 0) {
      dataGaps.push("We found competitor rates but not your own public rate. Confirm your listing or add your rate manually to compare.");
    }
  }

  const events = r.events(today, addDays(today, 30)).filter((e) => e.status !== "dismissed").slice(0, 3);
  for (const e of events) insights.push(eventInsight(e));

  const hour = hourIn(p.timeZone);
  const greeting = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening";
  const opportunities = insights.filter((i) => i.kind === "opportunity").length;
  const risks = insights.filter((i) => i.kind === "risk").length;
  const mood: Briefing["mood"] = headline.length === 0 ? "uncertainty" : opportunities > 0 ? "opportunity" : risks === 0 && insights.some((i) => i.title.includes("up")) ? "celebrating" : "explaining";

  const parts: string[] = [];
  const occ = headline.find((h) => h.key === "occupancy");
  const rp = headline.find((h) => h.key === "revpar");
  if (occ && occ.value !== null) parts.push(`Over the last 7 days you ran ${occ.formatted} occupancy${rp && rp.value !== null ? ` with RevPAR of ${rp.formatted}` : ""}.`);
  if (opportunities) parts.push(`I found ${opportunities} date${opportunities > 1 ? "s" : ""} worth a pricing review.`);
  if (events.length) parts.push(`${events.length} upcoming event${events.length > 1 ? "s" : ""} could affect demand.`);
  if (!parts.length) parts.push("I don't have enough of your data yet to brief you properly. Let's add your recent numbers first.");

  return {
    date: today,
    generatedAt: Date.now(),
    greeting,
    templateSummary: parts.join(" "),
    mood,
    headline,
    insights: insights.slice(0, 6),
    dataGaps: [...new Set(dataGaps)],
    hasSampleData,
  };
}

function eventInsight(e: EventRow): Insight {
  return {
    id: newId("ins", 8),
    kind: "info",
    title: `${formatDay(e.startDate)}: ${e.title}`,
    detail: `${e.venue ? `${e.venue}. ` : ""}${e.status === "confirmed" ? "Confirmed by your team." : "Unverified — check the source before acting."}`,
    evidence: [{ label: "Source", value: e.sourceTitle ?? e.sourceUrl ?? "Added manually", basis: "event", source: e.sourceUrl ?? "Manual", asOf: null }],
    labels: [e.status === "confirmed" ? "Confirmed" : "Unverified"],
    action: { label: "Open calendar", target: "calendar" },
    date: e.startDate,
  };
}

export function formatDay(iso: string): string {
  const d = new Date(`${iso}T12:00:00Z`);
  return d.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric", timeZone: "UTC" });
}

/** Optional Orev rephrasing of the summary. Rejected if it introduces numbers not in the facts. */
export async function narrate(env: Env, facts: string, template: string): Promise<{ text: string; costUsd: number } | null> {
  try {
    const res = await chat(env, {
      model: MODELS.orev,
      fallbackModel: MODELS.orevFallback,
      maxTokens: 220,
      temperature: 0.4,
      messages: [
        {
          role: "system",
          content:
            "You are Orev, a calm, precise hotel revenue consultant owl. Rewrite the briefing summary in 2–3 short sentences, warm and professional, second person. Use ONLY numbers that appear in the facts, exactly as written. Do not add advice beyond the facts. No emojis. No markdown.",
        },
        { role: "user", content: `Facts:\n${facts}\n\nDraft:\n${template}` },
      ],
    });
    const text = res.content.trim();
    const allowed = new Set((facts + " " + template).match(/\d[\d.,]*/g) ?? []);
    const used = text.match(/\d[\d.,]*/g) ?? [];
    if (!text || text.length > 600 || used.some((n) => !allowed.has(n.replace(/[.,]$/, "")) && !allowed.has(n))) return { text: template, costUsd: res.costUsd };
    return { text, costUsd: res.costUsd };
  } catch {
    return null;
  }
}

/* ------------------------------------------------------------------ */
/* Ask Orev — grounded tool use                                        */
/* ------------------------------------------------------------------ */

const TOOLS: ToolDef[] = [
  {
    type: "function",
    function: {
      name: "get_property",
      description: "Property profile: name, location, room count, currency, time zone, goals, tracked competitors and plan.",
      parameters: { type: "object", properties: {}, additionalProperties: false },
    },
  },
  {
    type: "function",
    function: {
      name: "get_performance",
      description:
        "Deterministic occupancy, ADR and RevPAR for a stay-date range, plus per-day rows. kind: actual (past), on_the_books (future reservations). Returns nulls when data is missing.",
      parameters: {
        type: "object",
        properties: {
          start: { type: "string", description: "YYYY-MM-DD" },
          end: { type: "string", description: "YYYY-MM-DD inclusive" },
          kind: { type: "string", enum: ["actual", "on_the_books"] },
        },
        required: ["start", "end", "kind"],
        additionalProperties: false,
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_booking_pace",
      description: "Booking pace (pickup) for future stay dates, computed only from two real on-the-books snapshots.",
      parameters: {
        type: "object",
        properties: { start: { type: "string" }, end: { type: "string" } },
        required: ["start", "end"],
        additionalProperties: false,
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_market_rates",
      description: "Lowest public OTA rates for the property and competitors by stay date (Beta, partial coverage), with market median and position.",
      parameters: {
        type: "object",
        properties: { start: { type: "string" }, end: { type: "string" } },
        required: ["start", "end"],
        additionalProperties: false,
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_events",
      description: "Local events on the property calendar in a date range, with source links and verification status.",
      parameters: {
        type: "object",
        properties: { start: { type: "string" }, end: { type: "string" } },
        required: ["start", "end"],
        additionalProperties: false,
      },
    },
  },
];

export type AskTurn = { role: "user" | "orev"; text: string };

export type AskResult = {
  answer: string;
  mood: "explaining" | "opportunity" | "uncertainty" | "celebrating";
  evidence: { tool: string; summary: string; basis: Evidence["basis"] }[];
  followUps: string[];
  costUsd: number;
  model: string;
};

function clampRange(start: unknown, end: unknown, today: string, maxDays = 190): [string, string] {
  let s = isIsoDate(start) ? start : today;
  let e = isIsoDate(end) ? end : addDays(s, 13);
  if (e < s) [s, e] = [e, s];
  if (Date.parse(e) - Date.parse(s) > maxDays * 86_400_000) e = addDays(s, maxDays);
  return [s, e];
}

function runTool(r: PropertyReader, name: string, args: Record<string, unknown>): { data: unknown; summary: string; basis: Evidence["basis"] } {
  const p = r.profile();
  const today = r.today();
  switch (name) {
    case "get_property": {
      const m = r.market(today, today);
      const plan = r.plan();
      return {
        data: {
          name: p.name,
          city: p.city,
          country: p.country,
          roomCount: p.roomCount,
          currency: p.currency,
          timeZone: p.timeZone,
          today,
          goals: p.goals,
          propertyType: p.propertyType,
          competitors: m.competitors.map((c) => c.name),
          plan: plan.plan,
        },
        summary: "Property profile",
        basis: "actual",
      };
    }
    case "get_performance": {
      const [s, e] = clampRange(args.start, args.end, today);
      const kind = args.kind === "on_the_books" ? "on_the_books" : "actual";
      const rows = r.performance(s, e).filter((x) => x.kind === kind);
      const days = Math.round((Date.parse(e) - Date.parse(s)) / 86_400_000) + 1;
      const agg = aggregate(rows, s, e, days);
      const sample = rows.some((x) => x.source === "sample");
      return {
        data: {
          range: { start: s, end: e },
          kind,
          isSampleData: sample,
          daysWithData: agg.daysWithData,
          daysInRange: days,
          roomsAvailable: agg.roomsAvailable,
          roomsSold: agg.roomsSold,
          roomRevenue: agg.roomRevenue,
          occupancy: agg.occupancy.value === null ? null : round(agg.occupancy.value, 4),
          adr: agg.adr.value === null ? null : round(agg.adr.value),
          revpar: agg.revpar.value === null ? null : round(agg.revpar.value),
          notes: [agg.occupancy.note, agg.adr.note, agg.revpar.note].filter(Boolean),
          daily: rows.slice(0, 60).map((x) => ({ date: x.date, available: x.roomsAvailable, sold: x.roomsSold, revenue: x.roomRevenue })),
        },
        summary: `${kind === "actual" ? "Performance" : "On the books"} ${s} → ${e} (${agg.daysWithData}/${days} days)`,
        basis: sample ? "sample" : kind === "actual" ? "actual" : "on_the_books",
      };
    }
    case "get_booking_pace": {
      const [s, e] = clampRange(args.start, args.end, today);
      const result = pace(r.snapshots(), s, e);
      return { data: result, summary: result.available ? `Booking pace ${s} → ${e}` : "Booking pace (not enough snapshots)", basis: "on_the_books" };
    }
    case "get_market_rates": {
      const [s, e] = clampRange(args.start, args.end, today, 60);
      const m: MarketSummary = r.market(s, e);
      return {
        data: {
          provider: m.provider,
          status: "Beta — partial coverage, lowest public price on listed OTAs, not your full rate grid",
          currency: m.currency,
          lastRefreshAt: m.lastRefreshAt ? new Date(m.lastRefreshAt).toISOString() : null,
          ownListingTracked: m.ownTracked,
          competitors: m.competitors,
          days: m.days.filter((d) => d.compCount > 0 || d.ownLowest !== null).map((d) => ({ ...d, positionVsMedian: d.positionVsMedian === null ? null : round(d.positionVsMedian, 3) })),
        },
        summary: `Public rates ${s} → ${e} (Beta)`,
        basis: "market",
      };
    }
    case "get_events": {
      const [s, e] = clampRange(args.start, args.end, today);
      const ev = r.events(s, e).filter((x) => x.status !== "dismissed");
      return {
        data: ev.map((x) => ({ title: x.title, start: x.startDate, end: x.endDate, venue: x.venue, category: x.category, status: x.status, source: x.sourceUrl })),
        summary: `Events ${s} → ${e} (${ev.length})`,
        basis: "event",
      };
    }
    default:
      return { data: { error: "unknown tool" }, summary: name, basis: "assumption" };
  }
}

const ASK_SYSTEM = `You are Orev, an owl who is a senior hotel revenue consultant inside the revOWL app. You are calm, precise and kind.

Rules you must follow:
- Ground every number in tool results. Call tools before answering anything about the property's performance, market, pace or events. Never invent or estimate metrics.
- Label numbers by basis: "actual", "on the books", "forecast", "public rates (Beta)", or "assumption". If a tool reports isSampleData=true, say it's sample data.
- If data is missing, say exactly what's missing and how to add it (import a report, enter numbers, add competitors, confirm an event). Do not fill gaps with guesses.
- Public rates are the lowest price on listed OTAs, partial coverage. They are not the full rate grid, don't include restrictions, and can be stale.
- Events marked unverified may be wrong; say so.
- Recommendations are suggestions for the user to review, never guarantees. You cannot change rates or anything else in their systems.
- Occupancy = rooms sold / rooms available. ADR = room revenue / rooms sold. RevPAR = room revenue / rooms available.
- Keep answers under 170 words. Plain text, short paragraphs or "- " bullets. No markdown headings, no emojis.
- End with a JSON block on its own line exactly like: <meta>{"mood":"explaining|opportunity|uncertainty|celebrating","followUps":["short question","short question"]}</meta>`;

export async function askOrev(env: Env, r: PropertyReader, question: string, history: AskTurn[]): Promise<AskResult> {
  const p = r.profile();
  const messages: ChatMessage[] = [
    { role: "system", content: `${ASK_SYSTEM}\n\nToday at the property is ${r.today()} (${p.timeZone}). Currency ${p.currency}. Property: ${p.name}.` },
    ...history.slice(-8).map((t): ChatMessage => (t.role === "user" ? { role: "user", content: t.text.slice(0, 1500) } : { role: "assistant", content: t.text.slice(0, 1500) })),
    { role: "user", content: question.slice(0, 1500) },
  ];
  const evidence: AskResult["evidence"] = [];
  let costUsd = 0;
  let model: string = MODELS.orev;
  for (let step = 0; step < 5; step++) {
    const res = await chat(env, { model: MODELS.orev, fallbackModel: MODELS.orevFallback, messages, tools: TOOLS, maxTokens: 900, temperature: 0.2 });
    costUsd += res.costUsd;
    model = res.model;
    if (res.toolCalls.length && step < 4) {
      messages.push({ role: "assistant", content: res.content || null, tool_calls: res.toolCalls });
      for (const call of res.toolCalls.slice(0, 5)) {
        let args: Record<string, unknown> = {};
        try {
          args = JSON.parse(call.function.arguments || "{}") as Record<string, unknown>;
        } catch {
          args = {};
        }
        const out = runTool(r, call.function.name, args);
        if (!evidence.some((e) => e.summary === out.summary)) evidence.push({ tool: call.function.name, summary: out.summary, basis: out.basis });
        messages.push({ role: "tool", tool_call_id: call.id, content: JSON.stringify(out.data).slice(0, 14_000) });
      }
      continue;
    }
    const raw = res.content ?? "";
    const metaMatch = raw.match(/<meta>([\s\S]*?)<\/meta>/i);
    const meta = metaMatch ? parseModelJson<{ mood?: string; followUps?: string[] }>(metaMatch[1]) : null;
    const answer = raw.replace(/<meta>[\s\S]*?<\/meta>/gi, "").replace(/^#+\s*/gm, "").replace(/\*\*/g, "").trim();
    const moods = ["explaining", "opportunity", "uncertainty", "celebrating"] as const;
    const mood = moods.find((m) => m === meta?.mood) ?? "explaining";
    return {
      answer: answer || "I couldn't form a reliable answer from your data. Could you rephrase or add more data?",
      mood,
      evidence,
      followUps: (meta?.followUps ?? []).filter((f): f is string => typeof f === "string").map((f) => f.slice(0, 80)).slice(0, 3),
      costUsd,
      model,
    };
  }
  return { answer: "I needed more steps than allowed to answer that. Try a narrower question.", mood: "uncertainty", evidence, followUps: [], costUsd, model };
}
