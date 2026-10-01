import { describe, expect, test } from "bun:test";
import { parseSubscriber } from "../_lib/billing";
import { importPerformanceCsv, parseDate, parseNumber } from "../_lib/csv";
import { aggregate, adr, marketDays, occupancy, pace, revpar, validateDaily, type DailyPerformance } from "../_lib/metrics";
import { effectivePlan, highestPlan, orevAllowance, PLANS, planForProduct } from "../_lib/plans";
import { validatePublicUrl } from "../_lib/safe-fetch";
import { addDays, todayIn } from "../_lib/util";
import { nameSimilarity } from "../_lib/xotelo";
import { normalizeEvents } from "../_lib/events";

describe("hotel matching", () => {
  test("city words don't create matches", () => {
    expect(nameSimilarity("Hilton Cabana Miami Beach", "Hilton Cabana Miami Beach Resort", "Miami Beach")).toBe(1);
    expect(nameSimilarity("Hilton Cabana Miami Beach", "Fontainebleau Miami Beach", "Miami Beach")).toBe(0);
  });
});

const row = (date: string, avail: number, sold: number, rev: number | null, source = "csv"): DailyPerformance => ({
  date,
  kind: "actual",
  roomsAvailable: avail,
  roomsSold: sold,
  roomRevenue: rev,
  source,
  capturedAt: 0,
});

describe("metrics", () => {
  test("basic formulas", () => {
    expect(occupancy(40, 50)).toBe(0.8);
    expect(adr(6000, 40)).toBe(150);
    expect(revpar(6000, 50)).toBe(120);
    expect(adr(null, 40)).toBeNull();
    expect(adr(100, 0)).toBeNull();
    expect(occupancy(1, 0)).toBeNull();
  });

  test("RevPAR equals ADR × occupancy", () => {
    const m = aggregate([row("2026-09-01", 50, 40, 6000), row("2026-09-02", 50, 20, 2400)], "2026-09-01", "2026-09-02", 2);
    expect(m.occupancy.value).toBeCloseTo(0.6);
    expect(m.adr.value).toBeCloseTo(140);
    expect(m.revpar.value).toBeCloseTo(84);
    expect(m.revpar.value!).toBeCloseTo(m.adr.value! * m.occupancy.value!);
  });

  test("sums numerators and denominators instead of averaging daily percentages", () => {
    const m = aggregate([row("2026-09-01", 100, 100, 10000), row("2026-09-02", 10, 0, 0)], "2026-09-01", "2026-09-02", 2);
    expect(m.occupancy.value).toBeCloseTo(100 / 110);
  });

  test("partial revenue suppresses ADR and RevPAR", () => {
    const m = aggregate([row("2026-09-01", 50, 40, 6000), row("2026-09-02", 50, 20, null)], "2026-09-01", "2026-09-02", 2);
    expect(m.occupancy.value).toBeCloseTo(0.6);
    expect(m.adr.value).toBeNull();
    expect(m.revpar.value).toBeNull();
    expect(m.revpar.note).toContain("missing");
  });

  test("no data returns nulls", () => {
    const m = aggregate([], "2026-09-01", "2026-09-07", 7);
    expect(m.occupancy.value).toBeNull();
    expect(m.daysWithData).toBe(0);
  });

  test("counts sample days", () => {
    const m = aggregate([row("2026-09-01", 50, 40, 6000, "sample")], "2026-09-01", "2026-09-01", 1);
    expect(m.sampleDays).toBe(1);
  });

  test("validation", () => {
    expect(validateDaily({ roomsAvailable: 10, roomsSold: 11, roomRevenue: 100 }, 1)).toHaveLength(1);
    expect(validateDaily({ roomsAvailable: 10, roomsSold: 0, roomRevenue: 100 }, 1)).toHaveLength(1);
    expect(validateDaily({ roomsAvailable: 0, roomsSold: 0, roomRevenue: null }, 1).length).toBeGreaterThan(0);
    expect(validateDaily({ roomsAvailable: 10, roomsSold: 5, roomRevenue: null }, 1)).toHaveLength(0);
  });
});

describe("pace", () => {
  test("requires two snapshots", () => {
    const r = pace([{ asOf: "2026-09-20", stayDate: "2026-10-01", roomsSold: 10, roomRevenue: null }], "2026-10-01", "2026-10-05");
    expect(r.available).toBe(false);
  });

  test("computes pickup on common stay dates only", () => {
    const r = pace(
      [
        { asOf: "2026-09-13", stayDate: "2026-10-01", roomsSold: 10, roomRevenue: null },
        { asOf: "2026-09-13", stayDate: "2026-10-02", roomsSold: 8, roomRevenue: null },
        { asOf: "2026-09-20", stayDate: "2026-10-01", roomsSold: 15, roomRevenue: null },
        { asOf: "2026-09-20", stayDate: "2026-10-02", roomsSold: 9, roomRevenue: null },
        { asOf: "2026-09-20", stayDate: "2026-10-03", roomsSold: 30, roomRevenue: null },
      ],
      "2026-10-01",
      "2026-10-05",
    );
    expect(r.available).toBe(true);
    expect(r.roomsThen).toBe(18);
    expect(r.roomsNow).toBe(24);
    expect(r.pickupRooms).toBe(6);
  });
});

describe("market", () => {
  test("median, rank and position", () => {
    const obs = [
      { hotelKey: "own", stayDate: "2026-10-01", channel: "A", rate: 90, currency: "USD", observedAt: 1 },
      { hotelKey: "c1", stayDate: "2026-10-01", channel: "A", rate: 100, currency: "USD", observedAt: 1 },
      { hotelKey: "c2", stayDate: "2026-10-01", channel: "A", rate: 120, currency: "USD", observedAt: 1 },
      { hotelKey: "c3", stayDate: "2026-10-01", channel: "A", rate: 80, currency: "USD", observedAt: 1 },
    ];
    const [d] = marketDays(obs, "own", ["c1", "c2", "c3"], ["2026-10-01"]);
    expect(d.compMedian).toBe(100);
    expect(d.rank).toBe(2);
    expect(d.positionVsMedian).toBeCloseTo(-0.1);
  });

  test("missing data stays null", () => {
    const [d] = marketDays([], "own", ["c1"], ["2026-10-01"]);
    expect(d.compMedian).toBeNull();
    expect(d.ownLowest).toBeNull();
    expect(d.compCount).toBe(0);
  });
});

describe("plans", () => {
  test("entitlement matrix", () => {
    expect(PLANS.essentials.limits.competitors).toBe(1);
    expect(PLANS.insight.limits.competitors).toBe(5);
    expect(PLANS.horizon.limits.competitors).toBe(9);
    expect(PLANS.insight.recommended).toBe(true);
    expect(orevAllowance("insight", "trial")).toBe(60);
    expect(orevAllowance("insight", "active")).toBe(250);
    expect(orevAllowance("horizon", "expired")).toBe(PLANS.none.limits.orevAnswersPerMonth);
  });

  test("resolution", () => {
    expect(highestPlan(["essentials", "horizon"])).toBe("horizon");
    expect(planForProduct("revowl_insight_monthly")).toBe("insight");
    expect(planForProduct("revowl_pro_monthly")).toBe("none");
    expect(effectivePlan("horizon", "expired")).toBe("none");
    expect(effectivePlan("horizon", "grace")).toBe("horizon");
  });

  test("cost ceilings", () => {
    expect(PLANS.essentials.limits.monthlyCostCeilingUsd).toBe(7);
    expect(PLANS.insight.limits.monthlyCostCeilingUsd).toBe(20);
    expect(PLANS.horizon.limits.monthlyCostCeilingUsd).toBe(40);
  });
});

describe("billing", () => {
  const future = new Date(Date.now() + 5 * 86_400_000).toISOString();
  const past = new Date(Date.now() - 5 * 86_400_000).toISOString();

  test("trial detected", () => {
    const s = parseSubscriber({
      subscriber: {
        entitlements: { insight: { expires_date: future, product_identifier: "revowl_insight_monthly" } },
        subscriptions: { revowl_insight_monthly: { expires_date: future, period_type: "trial" } },
      },
    });
    expect(s.plan).toBe("insight");
    expect(s.state).toBe("trial");
    expect(s.trialUsed).toBe(true);
  });

  test("expired", () => {
    const s = parseSubscriber({
      subscriber: {
        entitlements: { essentials: { expires_date: past, product_identifier: "revowl_essentials_monthly" } },
        subscriptions: { revowl_essentials_monthly: { expires_date: past, period_type: "normal" } },
      },
    });
    expect(s.plan).toBe("none");
    expect(s.state).toBe("expired");
  });

  test("renewal after cancellation flag", () => {
    const s = parseSubscriber({
      subscriber: {
        entitlements: { horizon: { expires_date: future, product_identifier: "revowl_horizon_monthly" } },
        subscriptions: { revowl_horizon_monthly: { expires_date: future, period_type: "normal", unsubscribe_detected_at: past } },
      },
    });
    expect(s.state).toBe("active");
    expect(s.willRenew).toBe(false);
  });
});

describe("csv", () => {
  test("numbers and dates", () => {
    expect(parseNumber("$1,234.50")).toBe(1234.5);
    expect(parseNumber("1.234,50")).toBe(1234.5);
    expect(parseNumber("12,5")).toBe(12.5);
    expect(parseDate("09/05/2026")).toBe("2026-09-05");
    expect(parseDate("05.09.2026")).toBe("2026-09-05");
    expect(parseDate("2026-02-30")).toBeNull();
  });

  test("import with issues", () => {
    const csv = "Date,Rooms Available,Rooms Sold,Room Revenue\n2026-09-01,50,40,6000\n2026-09-02,50,60,100\nnope,50,1,1\n2026-09-03,50,10,\n";
    const r = importPerformanceCsv(csv, null, "actual");
    expect(r.rows).toHaveLength(2);
    expect(r.rows[1].roomRevenue).toBeNull();
    expect(r.issues.length).toBe(2);
  });

  test("uses confirmed room count when column missing", () => {
    const r = importPerformanceCsv("date,sold,revenue\n2026-09-01,20,2000", 30, "actual");
    expect(r.rows[0].roomsAvailable).toBe(30);
  });

  test("rejects file without rooms sold", () => {
    const r = importPerformanceCsv("date,revenue\n2026-09-01,2000", 30, "actual");
    expect(r.rows).toHaveLength(0);
    expect(r.issues[0].field).toBe("roomsSold");
  });
});

describe("url safety", () => {
  test("accepts public sites", () => {
    expect(validatePublicUrl("hilton.com").toString()).toBe("https://hilton.com/");
    expect(validatePublicUrl("https://www.example-hotel.co.uk/rooms#x").toString()).toBe("https://www.example-hotel.co.uk/rooms");
  });

  for (const bad of ["http://localhost", "http://127.0.0.1", "http://10.0.0.1", "http://169.254.169.254/latest", "http://[::1]/", "ftp://example.com", "https://user:pw@example.com", "http://printer.local", "https://example.com:8080", "http://intranet", "https://x.rork.app"]) {
    test(`rejects ${bad}`, () => {
      expect(() => validatePublicUrl(bad)).toThrow();
    });
  }
});

describe("dates", () => {
  test("time zone today", () => {
    const now = new Date("2026-09-30T23:30:00Z");
    expect(todayIn("UTC", now)).toBe("2026-09-30");
    expect(todayIn("Asia/Tokyo", now)).toBe("2026-10-01");
    expect(todayIn("America/Los_Angeles", now)).toBe("2026-09-30");
    expect(addDays("2026-12-31", 1)).toBe("2027-01-01");
  });
});

describe("event normalization", () => {
  const range = { start: "2026-10-01", end: "2026-12-31" };
  test("tolerates null, strings and wrong shapes", () => {
    expect(normalizeEvents(null, range)).toEqual([]);
    expect(normalizeEvents("nope", range)).toEqual([]);
    expect(normalizeEvents({ events: "x" }, range)).toEqual([]);
    expect(normalizeEvents([null, 4, "a", ["b"]], range)).toEqual([]);
  });
  test("keeps valid events with public sources, drops the rest", () => {
    const out = normalizeEvents(
      {
        events: [
          { title: "Boat Show", start_date: "2026-10-10", end_date: "2026-10-12", source_url: "https://example.com/show", category: "exhibition" },
          { title: "No source", start_date: "2026-10-10" },
          { title: "Private", start_date: "2026-10-10", source_url: "http://10.0.0.1/x" },
          { title: "Out of range", start_date: "2027-03-01", source_url: "https://example.com/a" },
          { title: "Boat Show", start_date: "2026-10-10", source_url: "https://example.com/dup" },
          { title: 42, start_date: "2026-10-10", source_url: "https://example.com/b" },
        ],
      },
      range,
    );
    expect(out.length).toBe(1);
    expect(out[0].title).toBe("Boat Show");
    expect(out[0].category).toBe("exhibition");
  });
});
