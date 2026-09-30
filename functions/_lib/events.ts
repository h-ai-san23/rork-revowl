import { chat, MODELS, parseModelJson } from "./ai";
import type { Env } from "./env";
import { validatePublicUrl } from "./safe-fetch";
import { isIsoDate, mapLimit } from "./util";

export type DiscoveredEvent = {
  title: string;
  startDate: string;
  endDate: string;
  venue: string | null;
  category: string;
  sourceUrl: string;
  sourceTitle: string | null;
  expectedAttendance: number | null;
  sourceReachable: boolean;
};

const CATEGORIES = ["conference", "sports", "concert", "festival", "holiday", "exhibition", "community", "other"];

type RawEvent = {
  title?: string;
  start_date?: string;
  end_date?: string;
  venue?: string;
  category?: string;
  source_url?: string;
  source_title?: string;
  expected_attendance?: number | string | null;
};

export function normalizeTitle(t: string): string {
  return t
    .toLowerCase()
    .replace(/\b(20\d{2}|annual|the|festival|fest)\b/g, "")
    .replace(/[^a-z0-9]/g, "");
}

async function isReachable(url: string): Promise<boolean> {
  try {
    const u = validatePublicUrl(url);
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 6000);
    const res = await fetch(u.toString(), { method: "GET", redirect: "follow", signal: controller.signal, headers: { "User-Agent": "Mozilla/5.0 (compatible; RevOwlBot/1.0)" } });
    clearTimeout(timer);
    await res.body?.cancel();
    return res.status < 400;
  } catch {
    return false;
  }
}

/**
 * Discovers public events near a property using web-grounded search. Every event must
 * carry a source URL; events stay "unverified" in the product until a person confirms.
 */
export async function discoverEvents(
  env: Env,
  input: { city: string; region: string | null; country: string | null; start: string; end: string },
): Promise<{ events: DiscoveredEvent[]; costUsd: number }> {
  const place = [input.city, input.region, input.country].filter(Boolean).join(", ");
  const result = await chat(env, {
    model: MODELS.events,
    maxTokens: 2500,
    temperature: 0,
    timeoutMs: 60_000,
    messages: [
      {
        role: "system",
        content:
          "You find scheduled public events that can affect hotel demand. Only include events with a specific published date and a real source web page you found. Never invent events or URLs. If unsure, leave it out. Respond with JSON only.",
      },
      {
        role: "user",
        content: `List up to 20 notable events in or near ${place} taking place between ${input.start} and ${input.end}: conferences and trade shows, major sports, concerts, festivals, public holidays, large exhibitions.\nReturn a JSON array. Each item: {"title","start_date":"YYYY-MM-DD","end_date":"YYYY-MM-DD","venue","category":one of ${CATEGORIES.join("|")},"source_url","source_title","expected_attendance":number or null (only if the source states it)}.`,
      },
    ],
  });
  const raw = parseModelJson<RawEvent[] | { events?: RawEvent[] }>(result.content);
  const list = Array.isArray(raw) ? raw : raw?.events ?? [];
  const seen = new Set<string>();
  const cleaned: Omit<DiscoveredEvent, "sourceReachable">[] = [];
  for (const e of list) {
    const title = typeof e.title === "string" ? e.title.trim().slice(0, 140) : "";
    const start = e.start_date ?? "";
    const end = isIsoDate(e.end_date) ? e.end_date! : start;
    if (!title || !isIsoDate(start) || end < start || start > input.end || end < input.start) continue;
    let sourceUrl: string;
    try {
      sourceUrl = validatePublicUrl(String(e.source_url ?? "")).toString();
    } catch {
      continue; // no usable source → drop
    }
    const key = `${normalizeTitle(title)}|${start}`;
    if (seen.has(key)) continue;
    seen.add(key);
    const att = typeof e.expected_attendance === "number" ? e.expected_attendance : Number(e.expected_attendance);
    cleaned.push({
      title,
      startDate: start,
      endDate: end,
      venue: typeof e.venue === "string" ? e.venue.slice(0, 140) : null,
      category: CATEGORIES.includes(String(e.category)) ? String(e.category) : "other",
      sourceUrl,
      sourceTitle: typeof e.source_title === "string" ? e.source_title.slice(0, 160) : null,
      expectedAttendance: Number.isFinite(att) && att > 0 && att < 10_000_000 ? Math.round(att) : null,
    });
  }
  const reach = await mapLimit(cleaned, 5, (e) => isReachable(e.sourceUrl));
  return { events: cleaned.map((e, i) => ({ ...e, sourceReachable: reach[i] })), costUsd: result.costUsd };
}
