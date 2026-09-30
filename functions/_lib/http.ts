/** Typed HTTP error carrying a stable machine-readable code for clients. */
export class HttpError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
    public details?: unknown,
  ) {
    super(message);
  }
}

export function json(data: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store", ...headers },
  });
}

export function errorResponse(err: unknown): Response {
  if (err instanceof HttpError) {
    return json({ error: { code: err.code, message: err.message, details: err.details ?? null } }, err.status);
  }
  console.error("unhandled", err instanceof Error ? err.stack ?? err.message : String(err));
  return json({ error: { code: "internal", message: "Something went wrong on our side. Please try again.", details: null } }, 500);
}

/** Reads a JSON body with a size cap. Throws 400 on malformed input. */
export async function readJson<T>(request: Request, maxBytes = 512_000): Promise<T> {
  const text = await request.text();
  if (text.length > maxBytes) throw new HttpError(413, "payload_too_large", "Request body is too large.");
  if (!text) return {} as T;
  try {
    return JSON.parse(text) as T;
  } catch {
    throw new HttpError(400, "invalid_json", "Request body must be valid JSON.");
  }
}

/** Re-raises an error payload returned by an internal Durable Object call. */
export async function unwrap<T>(res: Response): Promise<T> {
  const text = await res.text();
  let body: unknown = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = null;
  }
  if (!res.ok) {
    const e = (body as { error?: { code?: string; message?: string; details?: unknown } } | null)?.error;
    throw new HttpError(res.status, e?.code ?? "upstream_error", e?.message ?? `Internal call failed (${res.status}).`, e?.details);
  }
  return body as T;
}
