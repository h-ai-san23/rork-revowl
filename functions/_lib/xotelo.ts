import { toolkitBase, type Env } from "./env";
import { mapLimit } from "./util";

/**
 * Xotelo (free, TripAdvisor-sourced) public rate adapter — BETA coverage.
 * Returns lowest publicly listed OTA prices for one night, as reported by Xotelo.
 * Empty results mean "no data", never "sold out".
 */
const BASE = "https://data.xotelo.com/api";

export type XoteloRate = { code: string; name: string; rate: number };

export type HotelCandidate = {
  key: string;
  name: string;
  url: string | null;
  latitude: number | null;
  longitude: number | null;
  distanceKm: number | null;
  rating: number | null;
  reviewCount: number | null;
  priceMin: number | null;
  priceMax: number | null;
  matchScore: number;
};

type ListItem = {
  name: string;
  key: string;
  url?: string;
  accommodation_type?: string;
  review_summary?: { rating?: number; count?: number };
  price_ranges?: { minimum?: number; maximum?: number };
  geo?: { latitude?: number; longitude?: number };
};

export function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const r = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a = Math.sin(dLat / 2) ** 2 + Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLon / 2) ** 2;
  return 2 * r * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

const STOP = new Set(["hotel", "hotels", "resort", "the", "and", "&", "by", "suites", "suite", "inn", "a", "of", "at", "spa"]);

function tokens(name: string): Set<string> {
  return new Set(
    name
      .toLowerCase()
      .normalize("NFKD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/[^a-z0-9 ]/g, " ")
      .split(/\s+/)
      .filter((t) => t.length > 1 && !STOP.has(t)),
  );
}

/** Token overlap on distinctive words; city words ("Miami Beach") are ignored. */
export function nameSimilarity(a: string, b: string, city: string | null = null): number {
  const cityTokens = city ? tokens(city) : new Set<string>();
  const ta = new Set([...tokens(a)].filter((t) => !cityTokens.has(t)));
  const tb = new Set([...tokens(b)].filter((t) => !cityTokens.has(t)));
  if (!ta.size || !tb.size) return 0;
  let inter = 0;
  for (const t of ta) if (tb.has(t)) inter++;
  return inter / Math.max(ta.size, tb.size);
}

async function getJson<T>(url: string, timeoutMs = 12_000): Promise<T | null> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { signal: controller.signal, headers: { Accept: "application/json" } });
    if (!res.ok) return null;
    return (await res.json()) as T;
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

export async function fetchRates(hotelKey: string, checkIn: string, checkOut: string, currency: string): Promise<XoteloRate[] | null> {
  const url = `${BASE}/rates?hotel_key=${encodeURIComponent(hotelKey)}&chk_in=${checkIn}&chk_out=${checkOut}&adults=2&currency=${encodeURIComponent(currency)}`;
  const body = await getJson<{ error: unknown; result: { rates?: { code: string; name: string; rate: number }[] } | null }>(url);
  if (!body || body.error || !body.result) return null;
  return (body.result.rates ?? []).filter((r) => typeof r.rate === "number" && r.rate > 0 && r.rate < 100_000);
}

async function listLocation(locationKey: string, pages = 3): Promise<ListItem[]> {
  const offsets = Array.from({ length: pages }, (_, i) => i * 100);
  const results = await mapLimit(offsets, 3, (offset) =>
    getJson<{ result: { list?: ListItem[] } | null }>(`${BASE}/list?location_key=${locationKey}&offset=${offset}&limit=100`),
  );
  const out: ListItem[] = [];
  for (const r of results) out.push(...(r?.result?.list ?? []));
  return out;
}

function toCandidate(item: ListItem, lat: number | null, lng: number | null, targetName: string | null, city: string | null = null): HotelCandidate {
  const ilat = item.geo?.latitude ?? null;
  const ilng = item.geo?.longitude ?? null;
  const distanceKm = lat !== null && lng !== null && ilat !== null && ilng !== null ? haversineKm(lat, lng, ilat, ilng) : null;
  const sim = targetName ? nameSimilarity(targetName, item.name, city) : 0;
  // Proximity only reinforces a name match; it never creates one.
  const geoScore = distanceKm === null ? 0 : (distanceKm < 0.3 ? 0.3 : distanceKm < 1 ? 0.15 : distanceKm < 3 ? 0.05 : -0.2) * Math.min(1, sim * 2);
  return {
    key: item.key,
    name: item.name,
    url: item.url ?? null,
    latitude: ilat,
    longitude: ilng,
    distanceKm: distanceKm === null ? null : Math.round(distanceKm * 100) / 100,
    rating: item.review_summary?.rating ?? null,
    reviewCount: item.review_summary?.count ?? null,
    priceMin: item.price_ranges?.minimum ?? null,
    priceMax: item.price_ranges?.maximum ?? null,
    matchScore: Math.round(Math.max(0, Math.min(1, sim * 0.75 + geoScore)) * 100) / 100,
  };
}

type ExaResult = { url: string; title?: string };

/** Finds TripAdvisor hotel/location keys for a hotel name via Exa web search. */
async function exaTripadvisor(env: Env, query: string): Promise<{ results: ExaResult[]; costUsd: number }> {
  const base = toolkitBase(env);
  const secret = env.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY;
  if (!secret) {
    console.warn("exa: toolkit secret missing");
    return { results: [], costUsd: 0 };
  }
  try {
    const res = await fetch(`${base}/v2/exa/search`, {
      method: "POST",
      headers: { Authorization: `Bearer ${secret}`, "Content-Type": "application/json" },
      body: JSON.stringify({ query, numResults: 8, includeDomains: ["tripadvisor.com"] }),
    });
    if (!res.ok) {
      console.warn("exa: search failed", res.status, (await res.text()).slice(0, 200));
      return { results: [], costUsd: 0 };
    }
    const body = (await res.json()) as { results?: ExaResult[]; costDollars?: { total?: number } };
    return { results: body.results ?? [], costUsd: body.costDollars?.total ?? 0.007 };
  } catch (e) {
    console.warn("exa: error", e instanceof Error ? e.message : String(e));
    return { results: [], costUsd: 0 };
  }
}

export type MatchResult = { candidates: HotelCandidate[]; locationKey: string | null; nearby: HotelCandidate[]; costUsd: number };

/**
 * Matches a property to Xotelo keys and returns nearby hotels for competitor suggestions.
 * The user always confirms the match; nothing is auto-selected.
 */
export async function matchHotel(
  env: Env,
  input: { name: string; city: string | null; latitude: number | null; longitude: number | null },
): Promise<MatchResult> {
  const q = `${input.name} ${input.city ?? ""} hotel`.trim();
  const { results, costUsd } = await exaTripadvisor(env, q);
  const found = new Map<string, { key: string; locationKey: string; slugName: string; url: string }>();
  for (const r of results) {
    const m = r.url.match(/Hotel_Review-(g\d+)-(d\d+)-Reviews-([^-]+)/);
    if (!m) continue;
    const key = `${m[1]}-${m[2]}`;
    if (!found.has(key)) found.set(key, { key, locationKey: m[1], slugName: decodeURIComponent(m[3]).replace(/_/g, " "), url: r.url });
  }
  const locationCounts = new Map<string, number>();
  for (const f of found.values()) locationCounts.set(f.locationKey, (locationCounts.get(f.locationKey) ?? 0) + 1);
  const locationKey = [...locationCounts.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] ?? null;

  const list = locationKey ? await listLocation(locationKey) : [];
  const byKey = new Map(list.map((i) => [i.key, i]));
  const candidates: HotelCandidate[] = [];
  for (const f of found.values()) {
    const item = byKey.get(f.key) ?? { key: f.key, name: f.slugName, url: f.url };
    candidates.push(toCandidate(item, input.latitude, input.longitude, input.name, input.city));
  }
  // Also consider list entries that are physically very close with a similar name.
  for (const item of list) {
    if (found.has(item.key)) continue;
    const c = toCandidate(item, input.latitude, input.longitude, input.name, input.city);
    if (c.matchScore >= 0.45) candidates.push(c);
  }
  candidates.sort((a, b) => b.matchScore - a.matchScore);

  const nearby =
    input.latitude !== null && input.longitude !== null
      ? list
          .map((i) => toCandidate(i, input.latitude, input.longitude, null))
          .filter((c) => c.distanceKm !== null && c.distanceKm <= 5)
          .sort((a, b) => (a.distanceKm ?? 99) - (b.distanceKm ?? 99))
          .slice(0, 40)
      : [];
  return { candidates: candidates.slice(0, 6), locationKey, nearby, costUsd };
}

/** Stay dates to sample: every day for two weeks, then weekly to the plan horizon. */
export function sampleStayDates(today: string, horizonDays: number): string[] {
  const out: string[] = [];
  const add = (n: number) => {
    const d = new Date(`${today}T00:00:00Z`);
    d.setUTCDate(d.getUTCDate() + n);
    out.push(d.toISOString().slice(0, 10));
  };
  for (let i = 0; i < Math.min(14, horizonDays); i++) add(i);
  for (let i = 14; i < horizonDays; i += 7) add(i);
  return out;
}
