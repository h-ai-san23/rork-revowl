import { chat, MODELS, parseModelJson, UNTRUSTED_RULE, untrusted } from "./ai";
import type { Env } from "./env";
import { extractJsonLd, extractMeta, htmlToText, safeFetchText } from "./safe-fetch";

export type Confidence = "high" | "medium" | "low";

export type ExtractedField<T> = {
  value: T;
  confidence: Confidence;
  /** Short verbatim quote from the page that supports the value. */
  evidence: string | null;
  source: "structured_data" | "page_text";
};

export type WebsiteExtraction = {
  sourceUrl: string;
  fetchedAt: number;
  fields: {
    name?: ExtractedField<string>;
    address?: ExtractedField<string>;
    city?: ExtractedField<string>;
    country?: ExtractedField<string>;
    phone?: ExtractedField<string>;
    email?: ExtractedField<string>;
    starRating?: ExtractedField<number>;
    roomCount?: ExtractedField<number>;
    checkInTime?: ExtractedField<string>;
    checkOutTime?: ExtractedField<string>;
    propertyType?: ExtractedField<string>;
    amenities?: ExtractedField<string[]>;
    description?: ExtractedField<string>;
  };
  /** Fields we deliberately never infer from marketing content. */
  notInferred: string[];
  warnings: string[];
  costUsd: number;
};

type LdNode = Record<string, unknown>;

const HOTEL_TYPES = ["Hotel", "LodgingBusiness", "Resort", "Motel", "BedAndBreakfast", "Hostel", "Campground", "VacationRental"];

function ldType(node: LdNode): string[] {
  const t = node["@type"];
  return Array.isArray(t) ? t.map(String) : typeof t === "string" ? [t] : [];
}

function str(v: unknown, max = 300): string | null {
  if (typeof v === "string" && v.trim()) return v.trim().slice(0, max);
  if (typeof v === "number") return String(v);
  return null;
}

function fromJsonLd(nodes: unknown[]): WebsiteExtraction["fields"] {
  const fields: WebsiteExtraction["fields"] = {};
  const hotel = nodes.find((n): n is LdNode => !!n && typeof n === "object" && ldType(n as LdNode).some((t) => HOTEL_TYPES.includes(t)));
  if (!hotel) return fields;
  const sd = <T,>(value: T, evidence: string | null = null): ExtractedField<T> => ({ confidence: "high", evidence, source: "structured_data", value });
  const name = str(hotel.name, 160);
  if (name) fields.name = sd(name, name);
  const addr = hotel.address as LdNode | string | undefined;
  if (typeof addr === "string") fields.address = sd(addr.slice(0, 300), addr.slice(0, 120));
  else if (addr && typeof addr === "object") {
    const parts = [addr.streetAddress, addr.addressLocality, addr.addressRegion, addr.postalCode, addr.addressCountry]
      .map((p) => (p && typeof p === "object" ? str((p as LdNode).name) : str(p)))
      .filter((p): p is string => !!p);
    if (parts.length) fields.address = sd(parts.join(", "), parts.join(", "));
    const city = str(addr.addressLocality, 100);
    if (city) fields.city = sd(city, city);
    const country = addr.addressCountry && typeof addr.addressCountry === "object" ? str((addr.addressCountry as LdNode).name) : str(addr.addressCountry, 60);
    if (country) fields.country = sd(country, country);
  }
  const phone = str(hotel.telephone, 40);
  if (phone) fields.phone = sd(phone, phone);
  const email = str(hotel.email, 120);
  if (email) fields.email = sd(email.replace(/^mailto:/i, ""), email);
  const stars = hotel.starRating as LdNode | undefined;
  const starVal = stars && typeof stars === "object" ? Number(stars.ratingValue) : NaN;
  if (Number.isFinite(starVal) && starVal >= 1 && starVal <= 7) fields.starRating = sd(starVal, `starRating ${starVal}`);
  const rooms = Number((hotel.numberOfRooms as LdNode | undefined)?.value ?? hotel.numberOfRooms);
  if (Number.isInteger(rooms) && rooms > 0 && rooms < 10_000) fields.roomCount = sd(rooms, `numberOfRooms ${rooms}`);
  const cin = str(hotel.checkinTime, 20);
  if (cin) fields.checkInTime = sd(cin, cin);
  const cout = str(hotel.checkoutTime, 20);
  if (cout) fields.checkOutTime = sd(cout, cout);
  const type = ldType(hotel).find((t) => HOTEL_TYPES.includes(t));
  if (type) fields.propertyType = sd(type, type);
  const amen = hotel.amenityFeature;
  if (Array.isArray(amen)) {
    const names = amen.map((a) => (a && typeof a === "object" ? str((a as LdNode).name, 60) : str(a, 60))).filter((a): a is string => !!a).slice(0, 20);
    if (names.length) fields.amenities = sd(names, names.slice(0, 5).join(", "));
  }
  return fields;
}

const EXTRACT_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["fields"],
  properties: {
    fields: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["field", "value", "evidence", "confidence"],
        properties: {
          field: {
            type: "string",
            enum: ["name", "address", "city", "country", "phone", "email", "starRating", "roomCount", "checkInTime", "checkOutTime", "propertyType", "amenities", "description"],
          },
          value: { type: "string" },
          evidence: { type: "string" },
          confidence: { type: "string", enum: ["high", "medium", "low"] },
        },
      },
    },
  },
} as const;

const NUMERIC_FIELDS = new Set(["starRating", "roomCount"]);

function normalizeForMatch(s: string): string {
  return s.toLowerCase().replace(/\s+/g, " ").trim();
}

/**
 * Website-assisted setup. Fetches the public page (SSRF-safe), reads structured data
 * first, then asks the model for fields it can quote verbatim. Any field whose quote
 * isn't actually on the page is downgraded to low confidence. Unknowns stay blank.
 */
export async function extractWebsite(env: Env, rawUrl: string): Promise<WebsiteExtraction> {
  const page = await safeFetchText(rawUrl, { maxBytes: 1_200_000 });
  const warnings: string[] = [];
  if (page.status >= 400) warnings.push(`The website responded with status ${page.status}.`);
  if (page.truncated) warnings.push("The page is very large; only the first part was read.");
  const ld = extractJsonLd(page.body);
  const meta = extractMeta(page.body);
  const text = htmlToText(page.body, 18_000);
  const fields = fromJsonLd(ld);
  let costUsd = 0;

  if (text.length > 200) {
    try {
      const metaLines = Object.entries(meta)
        .map(([k, v]) => `${k}: ${v}`)
        .join("\n");
      const result = await chat(env, {
        model: MODELS.extract,
        fallbackModel: MODELS.orevFallback,
        maxTokens: 900,
        temperature: 0,
        jsonSchema: { name: "hotel_fields", schema: EXTRACT_SCHEMA as unknown as Record<string, unknown> },
        messages: [
          {
            role: "system",
            content: [
              "You extract factual hotel profile fields from a hotel's own website for a setup form.",
              UNTRUSTED_RULE,
              "Only return a field when the page states it explicitly. For every field, `evidence` must be a short exact quote copied from the page (max 120 chars).",
              "Never guess or infer occupancy, ADR, room rates, revenue, inventory by date, or booking volume — those are not fields.",
              "roomCount only when the page explicitly states the total number of rooms/suites/keys for the property (not a single room type).",
              "starRating only when an official star classification is stated (not review scores).",
              "amenities: comma-separated list of up to 12 amenities.",
              "description: one neutral sentence under 200 chars summarising the property, using the page's own facts.",
              'Return JSON {"fields":[...]} and omit anything you are not sure about.',
            ].join("\n"),
          },
          { role: "user", content: `${untrusted("page_meta", metaLines)}\n\n${untrusted(page.finalUrl, text)}` },
        ],
      });
      costUsd += result.costUsd;
      const parsed = parseModelJson<{ fields?: { field: string; value: string; evidence: string; confidence: Confidence }[] }>(result.content);
      const haystack = normalizeForMatch(`${text}\n${Object.values(meta).join("\n")}`);
      for (const f of parsed?.fields ?? []) {
        const key = f.field as keyof WebsiteExtraction["fields"];
        if (fields[key]) continue; // structured data wins
        const value = String(f.value ?? "").trim().slice(0, 400);
        if (!value) continue;
        const evidence = String(f.evidence ?? "").trim().slice(0, 160);
        const quoted = evidence.length >= 3 && haystack.includes(normalizeForMatch(evidence));
        const confidence: Confidence = quoted ? (f.confidence === "high" ? "high" : f.confidence === "low" ? "low" : "medium") : "low";
        if (!quoted) warnings.push(`We couldn't find proof on the page for ${key}; please double-check it.`);
        const base = { confidence, evidence: quoted ? evidence : null, source: "page_text" as const };
        if (NUMERIC_FIELDS.has(key)) {
          const n = Number(value.replace(/[^\d.]/g, ""));
          if (!Number.isFinite(n) || n <= 0) continue;
          if (key === "roomCount" && (!Number.isInteger(n) || n > 10_000)) continue;
          if (key === "starRating" && n > 7) continue;
          (fields as Record<string, ExtractedField<number>>)[key] = { ...base, value: n };
        } else if (key === "amenities") {
          fields.amenities = { ...base, value: value.split(/[,;]/).map((a) => a.trim()).filter(Boolean).slice(0, 12) };
        } else {
          (fields as Record<string, ExtractedField<string>>)[key] = { ...base, value };
        }
      }
    } catch (e) {
      console.warn("website extraction model failed", e instanceof Error ? e.message : String(e));
      warnings.push("Orev couldn't read the page text, so only structured data was used.");
    }
  } else if (!Object.keys(fields).length) {
    warnings.push("The page had very little readable text. It may rely on JavaScript to load.");
  }

  if (!fields.name && meta["og:site_name"]) fields.name = { value: meta["og:site_name"], confidence: "medium", evidence: meta["og:site_name"], source: "page_text" };

  return {
    sourceUrl: page.finalUrl,
    fetchedAt: Date.now(),
    fields,
    notInferred: ["occupancy", "ADR", "RevPAR", "room revenue", "inventory by date", "booking pace"],
    warnings: [...new Set(warnings)].slice(0, 6),
    costUsd,
  };
}
