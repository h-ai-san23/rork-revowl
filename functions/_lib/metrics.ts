/**
 * Deterministic hotel metrics. No LLM is involved in any of these numbers.
 *
 * Definitions (USALI-aligned):
 *   Occupancy = rooms sold / rooms available
 *   ADR       = room revenue / rooms sold
 *   RevPAR    = room revenue / rooms available  (equivalently ADR × Occupancy)
 */
export type DataKind = "actual" | "on_the_books" | "forecast";

export type DailyPerformance = {
  date: string;
  kind: DataKind;
  roomsAvailable: number;
  roomsSold: number;
  roomRevenue: number | null;
  source: string;
  capturedAt: number;
};

export type MetricValue = {
  value: number | null;
  /** Why the value is null, or what it's based on. */
  note: string | null;
};

export type PeriodMetrics = {
  start: string;
  end: string;
  kind: DataKind | "mixed";
  daysWithData: number;
  daysInPeriod: number;
  /** Days in this period that come from labelled sample data rather than the property. */
  sampleDays: number;
  roomsAvailable: number;
  roomsSold: number;
  roomRevenue: number | null;
  occupancy: MetricValue;
  adr: MetricValue;
  revpar: MetricValue;
};

export type ValidationIssue = { row: number; field: string; message: string };

export function validateDaily(row: Partial<DailyPerformance>, index: number): ValidationIssue[] {
  const issues: ValidationIssue[] = [];
  const { roomsAvailable, roomsSold, roomRevenue } = row;
  if (typeof roomsAvailable !== "number" || !Number.isFinite(roomsAvailable) || roomsAvailable <= 0 || !Number.isInteger(roomsAvailable)) {
    issues.push({ row: index, field: "roomsAvailable", message: "Rooms available must be a whole number above 0." });
  }
  if (typeof roomsSold !== "number" || !Number.isFinite(roomsSold) || roomsSold < 0 || !Number.isInteger(roomsSold)) {
    issues.push({ row: index, field: "roomsSold", message: "Rooms sold must be a whole number of 0 or more." });
  }
  if (typeof roomsAvailable === "number" && typeof roomsSold === "number" && roomsSold > roomsAvailable) {
    issues.push({ row: index, field: "roomsSold", message: "Rooms sold can't exceed rooms available." });
  }
  if (roomRevenue !== null && roomRevenue !== undefined) {
    if (typeof roomRevenue !== "number" || !Number.isFinite(roomRevenue) || roomRevenue < 0) {
      issues.push({ row: index, field: "roomRevenue", message: "Room revenue must be 0 or more." });
    } else if (typeof roomsSold === "number" && roomsSold === 0 && roomRevenue > 0) {
      issues.push({ row: index, field: "roomRevenue", message: "Revenue is above 0 but no rooms were sold." });
    }
  }
  return issues;
}

export function occupancy(roomsSold: number, roomsAvailable: number): number | null {
  if (!(roomsAvailable > 0)) return null;
  return roomsSold / roomsAvailable;
}

export function adr(roomRevenue: number | null, roomsSold: number): number | null {
  if (roomRevenue === null || !(roomsSold > 0)) return null;
  return roomRevenue / roomsSold;
}

export function revpar(roomRevenue: number | null, roomsAvailable: number): number | null {
  if (roomRevenue === null || !(roomsAvailable > 0)) return null;
  return roomRevenue / roomsAvailable;
}

/**
 * Aggregates a period. Sums numerators and denominators across days (never averages
 * daily percentages). Revenue-based metrics are only reported when every day in the
 * aggregate has revenue, so ADR/RevPAR are never computed from a partial revenue set.
 */
export function aggregate(rows: DailyPerformance[], start: string, end: string, daysInPeriod: number): PeriodMetrics {
  const inRange = rows.filter((r) => r.date >= start && r.date <= end);
  const kinds = new Set(inRange.map((r) => r.kind));
  let roomsAvailable = 0;
  let roomsSold = 0;
  let revenue = 0;
  let revenueComplete = inRange.length > 0;
  for (const r of inRange) {
    roomsAvailable += r.roomsAvailable;
    roomsSold += r.roomsSold;
    if (r.roomRevenue === null) revenueComplete = false;
    else revenue += r.roomRevenue;
  }
  const roomRevenue = revenueComplete ? revenue : null;
  const noData = inRange.length === 0 ? "No data for this period yet." : null;
  const noRevenue = noData ?? (revenueComplete ? null : "Room revenue is missing for some days.");
  return {
    start,
    end,
    kind: kinds.size === 1 ? [...kinds][0] : kinds.size === 0 ? "actual" : "mixed",
    daysWithData: inRange.length,
    daysInPeriod,
    sampleDays: inRange.filter((r) => r.source === "sample").length,
    roomsAvailable,
    roomsSold,
    roomRevenue,
    occupancy: { value: occupancy(roomsSold, roomsAvailable), note: noData },
    adr: { value: adr(roomRevenue, roomsSold), note: noRevenue ?? (roomsSold === 0 ? "No rooms sold." : null) },
    revpar: { value: revpar(roomRevenue, roomsAvailable), note: noRevenue },
  };
}

export type OtbSnapshotRow = { asOf: string; stayDate: string; roomsSold: number; roomRevenue: number | null };

export type PaceResult = {
  available: boolean;
  reason: string | null;
  asOf: string | null;
  comparedTo: string | null;
  stayStart: string;
  stayEnd: string;
  roomsNow: number | null;
  roomsThen: number | null;
  pickupRooms: number | null;
  revenueNow: number | null;
  revenueThen: number | null;
};

/**
 * Booking pace = change in on-the-books rooms for the same future stay dates between two
 * snapshots. Only computed when two real snapshots cover the stay window; never estimated.
 */
export function pace(snapshots: OtbSnapshotRow[], stayStart: string, stayEnd: string, minGapDays = 1): PaceResult {
  const base: PaceResult = {
    available: false,
    reason: null,
    asOf: null,
    comparedTo: null,
    stayStart,
    stayEnd,
    roomsNow: null,
    roomsThen: null,
    pickupRooms: null,
    revenueNow: null,
    revenueThen: null,
  };
  const asOfs = [...new Set(snapshots.map((s) => s.asOf))].sort();
  if (asOfs.length < 2) {
    return { ...base, reason: "Booking pace needs at least two on-the-books snapshots taken on different days." };
  }
  const latest = asOfs[asOfs.length - 1];
  const earlier = asOfs.filter((a) => Date.parse(latest) - Date.parse(a) >= minGapDays * 86_400_000);
  if (earlier.length === 0) return { ...base, reason: "Snapshots are too close together to measure pace." };
  const then = earlier[earlier.length - 1];
  const window = (asOf: string) => snapshots.filter((s) => s.asOf === asOf && s.stayDate >= stayStart && s.stayDate <= stayEnd && s.stayDate >= latest);
  const nowRows = window(latest);
  const thenRows = window(then);
  const nowDates = new Set(nowRows.map((r) => r.stayDate));
  const common = thenRows.filter((r) => nowDates.has(r.stayDate));
  if (common.length === 0) return { ...base, asOf: latest, comparedTo: then, reason: "The two snapshots don't cover the same stay dates." };
  const commonDates = new Set(common.map((r) => r.stayDate));
  const nowCommon = nowRows.filter((r) => commonDates.has(r.stayDate));
  const sum = (rows: OtbSnapshotRow[]) => rows.reduce((a, r) => a + r.roomsSold, 0);
  const sumRev = (rows: OtbSnapshotRow[]) => (rows.every((r) => r.roomRevenue !== null) ? rows.reduce((a, r) => a + (r.roomRevenue ?? 0), 0) : null);
  const roomsNow = sum(nowCommon);
  const roomsThen = sum(common);
  return {
    ...base,
    available: true,
    asOf: latest,
    comparedTo: then,
    roomsNow,
    roomsThen,
    pickupRooms: roomsNow - roomsThen,
    revenueNow: sumRev(nowCommon),
    revenueThen: sumRev(common),
  };
}

export type RateObservation = {
  hotelKey: string;
  stayDate: string;
  channel: string;
  rate: number;
  currency: string;
  observedAt: number;
};

export type MarketDay = {
  stayDate: string;
  ownLowest: number | null;
  compLowest: number | null;
  compMedian: number | null;
  compHighest: number | null;
  compCount: number;
  /** Own lowest rate relative to competitor median, e.g. -0.12 = 12% below. */
  positionVsMedian: number | null;
  rank: number | null;
  observedAt: number | null;
};

/** Per-date market summary from the latest observation of each hotel's lowest public rate. */
export function marketDays(obs: RateObservation[], ownKey: string | null, compKeys: string[], dates: string[]): MarketDay[] {
  const lowest = new Map<string, { rate: number; at: number }>();
  for (const o of obs) {
    const k = `${o.hotelKey}|${o.stayDate}`;
    const cur = lowest.get(k);
    if (!cur || o.observedAt > cur.at + 60_000 || (Math.abs(o.observedAt - cur.at) <= 60_000 && o.rate < cur.rate)) {
      lowest.set(k, { rate: o.rate, at: o.observedAt });
    }
  }
  return dates.map((d) => {
    const own = ownKey ? lowest.get(`${ownKey}|${d}`) ?? null : null;
    const comps = compKeys.map((c) => lowest.get(`${c}|${d}`)).filter((x): x is { rate: number; at: number } => !!x);
    const rates = comps.map((c) => c.rate).sort((a, b) => a - b);
    const med = rates.length ? (rates.length % 2 ? rates[(rates.length - 1) / 2] : (rates[rates.length / 2 - 1] + rates[rates.length / 2]) / 2) : null;
    const ownRate = own?.rate ?? null;
    let rank: number | null = null;
    if (ownRate !== null && rates.length) rank = rates.filter((r) => r < ownRate).length + 1;
    const times = [own?.at, ...comps.map((c) => c.at)].filter((t): t is number => typeof t === "number");
    return {
      stayDate: d,
      ownLowest: ownRate,
      compLowest: rates[0] ?? null,
      compMedian: med,
      compHighest: rates[rates.length - 1] ?? null,
      compCount: rates.length,
      positionVsMedian: ownRate !== null && med ? (ownRate - med) / med : null,
      rank,
      observedAt: times.length ? Math.max(...times) : null,
    };
  });
}
