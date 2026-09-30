import type { BillingSnapshot } from "./billing";
import type { DailyPerformance, MarketDay, OtbSnapshotRow } from "./metrics";
import type { PlanId, BillingState } from "./plans";

export type FieldSource = { source: "user" | "website" | "maps"; confidence?: "high" | "medium" | "low"; url?: string; confirmedAt?: number };

export type Profile = {
  id: string;
  name: string;
  address: string | null;
  city: string | null;
  region: string | null;
  country: string | null;
  countryCode: string | null;
  latitude: number | null;
  longitude: number | null;
  timeZone: string;
  currency: string;
  roomCount: number | null;
  website: string | null;
  phone: string | null;
  starRating: number | null;
  propertyType: string | null;
  amenities: string[];
  description: string | null;
  goals: string[];
  /** Xotelo/TripAdvisor key for the property's own public listing, confirmed by the user. */
  xoteloKey: string | null;
  xoteloName: string | null;
  setupStep: string;
  setupCompleted: boolean;
  fieldSources: Record<string, FieldSource>;
  createdAt: number;
  updatedAt: number;
};

export type Competitor = {
  id: string;
  name: string;
  xoteloKey: string | null;
  latitude: number | null;
  longitude: number | null;
  distanceKm: number | null;
  rating: number | null;
  priority: number;
  active: boolean;
  addedAt: number;
};

export type EventStatus = "unverified" | "confirmed" | "dismissed";

export type EventRow = {
  id: string;
  title: string;
  startDate: string;
  endDate: string;
  venue: string | null;
  category: string;
  sourceUrl: string | null;
  sourceTitle: string | null;
  expectedAttendance: number | null;
  sourceReachable: boolean;
  status: EventStatus;
  origin: "discovered" | "manual";
  createdAt: number;
};

export type EvidenceBasis = "actual" | "on_the_books" | "forecast" | "market" | "event" | "assumption" | "sample";

export type Evidence = { label: string; value: string; basis: EvidenceBasis; source: string; asOf: string | null };

export type Insight = {
  id: string;
  kind: "opportunity" | "risk" | "info" | "action";
  title: string;
  detail: string;
  evidence: Evidence[];
  labels: string[];
  action: { label: string; target: "import" | "market" | "calendar" | "competitors" | "ask" | "property" } | null;
  date: string | null;
};

export type HeadlineMetric = { key: string; label: string; value: number | null; formatted: string; basis: EvidenceBasis; period: string; note: string | null };

export type Briefing = {
  date: string;
  generatedAt: number;
  greeting: string;
  summary: string;
  summarySource: "orev" | "template";
  mood: "explaining" | "opportunity" | "uncertainty" | "celebrating";
  headline: HeadlineMetric[];
  insights: Insight[];
  dataGaps: string[];
  hasSampleData: boolean;
};

export type PerformanceRow = DailyPerformance;

export type MarketSummary = {
  provider: string;
  providerStatus: "beta";
  currency: string;
  lastRefreshAt: number | null;
  ownTracked: boolean;
  competitors: { id: string; name: string; hasData: boolean; active: boolean }[];
  days: MarketDay[];
  byHotel: Record<string, Record<string, { rate: number; channel: string; observedAt: number; manual: boolean }>>;
};

/** Read-only data access the Orev layer uses. Implemented by the Property Durable Object. */
export interface PropertyReader {
  profile(): Profile;
  today(): string;
  performance(start: string, end: string): PerformanceRow[];
  snapshots(): OtbSnapshotRow[];
  market(start: string, end: string): MarketSummary;
  events(start: string, end: string): EventRow[];
  plan(): { plan: PlanId; state: BillingState; billing: BillingSnapshot | null };
}
