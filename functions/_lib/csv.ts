import { validateDaily, type DataKind, type ValidationIssue } from "./metrics";
import { isIsoDate } from "./util";

/** Minimal RFC 4180 parser (quoted fields, escaped quotes, CRLF). */
export function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let field = "";
  let row: string[] = [];
  let inQuotes = false;
  const src = text.replace(/^\uFEFF/, "");
  for (let i = 0; i < src.length; i++) {
    const c = src[i];
    if (inQuotes) {
      if (c === '"') {
        if (src[i + 1] === '"') {
          field += '"';
          i++;
        } else inQuotes = false;
      } else field += c;
      continue;
    }
    if (c === '"') inQuotes = true;
    else if (c === "," || c === ";" || c === "\t") {
      row.push(field);
      field = "";
    } else if (c === "\n" || c === "\r") {
      if (c === "\r" && src[i + 1] === "\n") i++;
      row.push(field);
      if (row.some((f) => f.trim() !== "")) rows.push(row);
      row = [];
      field = "";
    } else field += c;
  }
  row.push(field);
  if (row.some((f) => f.trim() !== "")) rows.push(row);
  return rows;
}

const HEADER_ALIASES: Record<string, string[]> = {
  date: ["date", "stay date", "stay_date", "business date", "night", "day"],
  roomsAvailable: ["rooms available", "rooms_available", "available rooms", "capacity", "inventory", "rooms"],
  roomsSold: ["rooms sold", "rooms_sold", "sold", "occupied rooms", "room nights", "roomnights", "occupied"],
  roomRevenue: ["room revenue", "room_revenue", "revenue", "rooms revenue", "total room revenue"],
  asOf: ["as of", "as_of", "snapshot date", "report date"],
};

function normalizeHeader(h: string): string {
  return h.trim().toLowerCase().replace(/\s+/g, " ").replace(/[()$€£]/g, "").trim();
}

export type CsvColumnMap = Partial<Record<keyof typeof HEADER_ALIASES, number>>;

export function detectColumns(header: string[]): CsvColumnMap {
  const map: CsvColumnMap = {};
  header.forEach((raw, idx) => {
    const h = normalizeHeader(raw);
    for (const [key, aliases] of Object.entries(HEADER_ALIASES)) {
      if (map[key as keyof CsvColumnMap] === undefined && aliases.includes(h)) {
        map[key as keyof CsvColumnMap] = idx;
      }
    }
  });
  return map;
}

/** Parses numbers such as "1,234.50", "$1 234", "1.234,50" (EU). */
export function parseNumber(raw: string | undefined): number | null {
  if (raw === undefined) return null;
  let s = raw.trim().replace(/[\s$€£¥]/g, "");
  if (!s) return null;
  if (/^-?\d{1,3}(\.\d{3})+(,\d+)?$/.test(s)) s = s.replace(/\./g, "").replace(",", ".");
  else if (/^-?\d+,\d{1,2}$/.test(s)) s = s.replace(",", ".");
  else s = s.replace(/,/g, "");
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}

/** Accepts ISO, MM/DD/YYYY, DD.MM.YYYY. Ambiguous slash dates are read as US format. */
export function parseDate(raw: string | undefined): string | null {
  if (!raw) return null;
  const s: string = raw.trim();
  if (isIsoDate(String(s))) return s;
  const iso = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/);
  const us = s.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
  const eu = s.match(/^(\d{1,2})\.(\d{1,2})\.(\d{4})$/);
  let y: string, m: string, d: string;
  if (iso) [, y, m, d] = iso;
  else if (us) [, m, d, y] = us;
  else if (eu) [, d, m, y] = eu;
  else return null;
  const out = `${y}-${m.padStart(2, "0")}-${d.padStart(2, "0")}`;
  return isIsoDate(out) ? out : null;
}

export type ParsedPerformanceRow = {
  date: string;
  roomsAvailable: number;
  roomsSold: number;
  roomRevenue: number | null;
  asOf: string | null;
};

export type CsvImportResult = {
  rows: ParsedPerformanceRow[];
  issues: ValidationIssue[];
  columns: CsvColumnMap;
  totalLines: number;
};

/**
 * Parses a performance CSV. Missing rooms-available falls back to the property's
 * confirmed room count; nothing else is ever filled in or guessed.
 */
export function importPerformanceCsv(text: string, fallbackRoomsAvailable: number | null, kind: DataKind): CsvImportResult {
  const table = parseCsv(text);
  const issues: ValidationIssue[] = [];
  if (table.length < 2) {
    return { rows: [], issues: [{ row: 0, field: "file", message: "The file needs a header row and at least one data row." }], columns: {}, totalLines: table.length };
  }
  const columns = detectColumns(table[0]);
  if (columns.date === undefined) issues.push({ row: 1, field: "date", message: "Couldn't find a date column." });
  if (columns.roomsSold === undefined) issues.push({ row: 1, field: "roomsSold", message: "Couldn't find a rooms sold column." });
  if (columns.roomsAvailable === undefined && !fallbackRoomsAvailable) {
    issues.push({ row: 1, field: "roomsAvailable", message: "Add a rooms available column, or confirm your room count first." });
  }
  if (issues.length) return { rows: [], issues, columns, totalLines: table.length };

  const rows: ParsedPerformanceRow[] = [];
  const seen = new Set<string>();
  for (let i = 1; i < table.length && i <= 1500; i++) {
    const line = table[i];
    const lineNo = i + 1;
    const date = parseDate(line[columns.date!]);
    if (!date) {
      issues.push({ row: lineNo, field: "date", message: `"${(line[columns.date!] ?? "").slice(0, 20)}" isn't a date we can read.` });
      continue;
    }
    const asOf = columns.asOf !== undefined ? parseDate(line[columns.asOf]) : null;
    const key = `${date}|${asOf ?? ""}`;
    if (seen.has(key)) {
      issues.push({ row: lineNo, field: "date", message: `${date} appears more than once.` });
      continue;
    }
    const roomsAvailable = columns.roomsAvailable !== undefined ? parseNumber(line[columns.roomsAvailable]) : fallbackRoomsAvailable;
    const roomsSold = parseNumber(line[columns.roomsSold!]);
    const roomRevenue = columns.roomRevenue !== undefined ? parseNumber(line[columns.roomRevenue]) : null;
    const candidate = { date, kind, roomsAvailable: roomsAvailable ?? NaN, roomsSold: roomsSold ?? NaN, roomRevenue };
    const rowIssues = validateDaily(candidate, lineNo);
    if (rowIssues.length) {
      issues.push(...rowIssues);
      continue;
    }
    seen.add(key);
    rows.push({ date, roomsAvailable: candidate.roomsAvailable, roomsSold: candidate.roomsSold, roomRevenue, asOf });
  }
  if (table.length > 1501) issues.push({ row: 1502, field: "file", message: "Only the first 1,500 rows were read." });
  return { rows, issues, columns, totalLines: table.length };
}
