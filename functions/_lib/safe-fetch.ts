import { HttpError } from "./http";

/**
 * Outbound fetch for user-supplied URLs (hotel websites, event sources).
 * Everything fetched here is UNTRUSTED DATA: it is size-capped, text-only, and
 * never executed or followed as instructions.
 */
const BLOCKED_HOSTS = new Set(["localhost", "localhost.localdomain", "metadata.google.internal", "metadata", "internal"]);
const BLOCKED_SUFFIXES = [".local", ".localhost", ".internal", ".lan", ".home", ".corp", ".intranet", ".rork.app", ".workers.dev"];

function isPrivateIPv4(host: string): boolean {
  const m = host.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (!m) return false;
  const [a, b] = [Number(m[1]), Number(m[2])];
  if ([a, b, Number(m[3]), Number(m[4])].some((n) => n > 255)) return true;
  return (
    a === 0 || a === 10 || a === 127 || (a === 100 && b >= 64 && b <= 127) || (a === 169 && b === 254) ||
    (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168) || (a === 192 && b === 0) ||
    (a === 198 && (b === 18 || b === 19)) || a >= 224
  );
}

/** Returns a normalized URL or throws a user-facing 400 when the URL is unsafe or malformed. */
export function validatePublicUrl(raw: string): URL {
  let input = raw.trim();
  if (!input) throw new HttpError(400, "invalid_url", "Enter a website address.");
  if (!/^[a-z][a-z0-9+.-]*:\/\//i.test(input)) input = `https://${input}`;
  let url: URL;
  try {
    url = new URL(input);
  } catch {
    throw new HttpError(400, "invalid_url", "That doesn't look like a website address.");
  }
  if (url.protocol !== "https:" && url.protocol !== "http:") throw new HttpError(400, "invalid_url", "Only http and https websites are supported.");
  if (url.username || url.password) throw new HttpError(400, "invalid_url", "Website addresses with credentials aren't allowed.");
  if (url.port && url.port !== "80" && url.port !== "443") throw new HttpError(400, "invalid_url", "Only standard web ports are supported.");
  const host = url.hostname.toLowerCase().replace(/\.$/, "");
  if (!host.includes(".") || BLOCKED_HOSTS.has(host) || BLOCKED_SUFFIXES.some((s) => host.endsWith(s))) {
    throw new HttpError(400, "invalid_url", "That website address can't be reached publicly.");
  }
  if (host.startsWith("[") || host.includes(":")) throw new HttpError(400, "invalid_url", "IP address websites aren't supported.");
  if (/^[\d.]+$/.test(host)) {
    if (isPrivateIPv4(host)) throw new HttpError(400, "invalid_url", "That website address can't be reached publicly.");
    throw new HttpError(400, "invalid_url", "IP address websites aren't supported.");
  }
  if (host.length > 253) throw new HttpError(400, "invalid_url", "That website address is too long.");
  url.hash = "";
  return url;
}

export type SafeFetchResult = { finalUrl: string; status: number; contentType: string; body: string; truncated: boolean };

export async function safeFetchText(
  raw: string,
  opts: { maxBytes?: number; timeoutMs?: number; maxRedirects?: number; accept?: string } = {},
): Promise<SafeFetchResult> {
  const maxBytes = opts.maxBytes ?? 1_500_000;
  const maxRedirects = opts.maxRedirects ?? 4;
  let url = validatePublicUrl(raw);
  for (let hop = 0; hop <= maxRedirects; hop++) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), opts.timeoutMs ?? 10_000);
    let res: Response;
    try {
      res = await fetch(url.toString(), {
        method: "GET",
        redirect: "manual",
        signal: controller.signal,
        headers: {
          "User-Agent": "Mozilla/5.0 (compatible; RevOwlBot/1.0; +https://revowl.app/bot)",
          Accept: opts.accept ?? "text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.5",
          "Accept-Language": "en;q=0.9,*;q=0.5",
        },
      });
    } catch (e) {
      clearTimeout(timer);
      const aborted = e instanceof Error && e.name === "AbortError";
      throw new HttpError(502, "fetch_failed", aborted ? "The website took too long to respond." : "We couldn't reach that website.");
    }
    if (res.status >= 300 && res.status < 400) {
      clearTimeout(timer);
      const loc = res.headers.get("Location");
      if (!loc) throw new HttpError(502, "fetch_failed", "The website redirected without a destination.");
      url = validatePublicUrl(new URL(loc, url).toString());
      continue;
    }
    const contentType = (res.headers.get("Content-Type") ?? "").toLowerCase();
    if (contentType && !/text\/|json|xml/.test(contentType)) {
      clearTimeout(timer);
      throw new HttpError(415, "unsupported_content", "That address isn't a web page.");
    }
    const reader = res.body?.getReader();
    let received = 0;
    let truncated = false;
    const chunks: Uint8Array[] = [];
    if (reader) {
      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          received += value.byteLength;
          if (received > maxBytes) {
            chunks.push(value.slice(0, value.byteLength - (received - maxBytes)));
            truncated = true;
            await reader.cancel();
            break;
          }
          chunks.push(value);
        }
      } finally {
        clearTimeout(timer);
      }
    } else clearTimeout(timer);
    const buf = new Uint8Array(chunks.reduce((a, c) => a + c.byteLength, 0));
    let off = 0;
    for (const c of chunks) {
      buf.set(c, off);
      off += c.byteLength;
    }
    return { finalUrl: url.toString(), status: res.status, contentType, body: new TextDecoder("utf-8").decode(buf), truncated };
  }
  throw new HttpError(502, "fetch_failed", "The website redirected too many times.");
}

/** Strips scripts/styles/markup to readable text. */
export function htmlToText(html: string, maxChars = 24_000): string {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<noscript[\s\S]*?<\/noscript>/gi, " ")
    .replace(/<!--[\s\S]*?-->/g, " ")
    .replace(/<(br|p|div|li|h[1-6]|tr|section|article|footer|header)[^>]*>/gi, "\n")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/[ \t\f\v]+/g, " ")
    .replace(/\n\s*\n+/g, "\n")
    .trim()
    .slice(0, maxChars);
}

export function extractJsonLd(html: string): unknown[] {
  const out: unknown[] = [];
  const re = /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  let m: RegExpExecArray | null;
  while ((m = re.exec(html)) && out.length < 20) {
    try {
      const parsed = JSON.parse(m[1].trim());
      if (Array.isArray(parsed)) out.push(...parsed);
      else if (parsed && typeof parsed === "object" && Array.isArray((parsed as { "@graph"?: unknown[] })["@graph"])) out.push(...(parsed as { "@graph": unknown[] })["@graph"]);
      else out.push(parsed);
    } catch {
      // malformed JSON-LD is ignored
    }
  }
  return out;
}

export function extractMeta(html: string): Record<string, string> {
  const meta: Record<string, string> = {};
  const title = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  if (title) meta.title = htmlToText(title[1], 200);
  const re = /<meta\s+[^>]*(?:name|property)=["']([^"']+)["'][^>]*content=["']([^"']*)["'][^>]*>/gi;
  let m: RegExpExecArray | null;
  while ((m = re.exec(html)) && Object.keys(meta).length < 40) {
    const k = m[1].toLowerCase();
    if (/^(description|og:title|og:site_name|og:description|og:locale|geo\.|place:|business:)/.test(k)) meta[k] = m[2].slice(0, 400);
  }
  return meta;
}
