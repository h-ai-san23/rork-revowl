import { HttpError } from "./http";
import { base64urlDecode, sha256Hex } from "./util";

type AppleJwk = JsonWebKey & { kid: string; alg: string };

let jwksCache: { keys: AppleJwk[]; fetchedAt: number } | null = null;

async function appleKeys(force = false): Promise<AppleJwk[]> {
  if (!force && jwksCache && Date.now() - jwksCache.fetchedAt < 3_600_000) return jwksCache.keys;
  const res = await fetch("https://appleid.apple.com/auth/keys", { headers: { Accept: "application/json" } });
  if (!res.ok) throw new HttpError(503, "apple_unavailable", "Apple sign-in is temporarily unavailable. Please try again.");
  const body = (await res.json()) as { keys?: AppleJwk[] };
  jwksCache = { keys: body.keys ?? [], fetchedAt: Date.now() };
  return jwksCache.keys;
}

export type AppleIdentity = {
  sub: string;
  email: string | null;
  emailVerified: boolean;
  isPrivateEmail: boolean;
};

function decodeJson<T>(segment: string): T {
  try {
    return JSON.parse(new TextDecoder().decode(base64urlDecode(segment))) as T;
  } catch {
    throw new HttpError(401, "invalid_token", "The Apple sign-in token couldn't be read.");
  }
}

/**
 * Verifies a Sign in with Apple identity token (RS256 JWT) against Apple's published
 * keys, issuer, audience (our bundle ids), expiry, and the SHA-256 of the client nonce.
 */
export async function verifyAppleIdentityToken(token: string, audiences: string[], rawNonce: string | null): Promise<AppleIdentity> {
  const parts = token.split(".");
  if (parts.length !== 3) throw new HttpError(401, "invalid_token", "The Apple sign-in token is malformed.");
  const header = decodeJson<{ kid?: string; alg?: string }>(parts[0]);
  const payload = decodeJson<{
    iss?: string;
    aud?: string | string[];
    exp?: number;
    iat?: number;
    sub?: string;
    nonce?: string;
    email?: string;
    email_verified?: boolean | string;
    is_private_email?: boolean | string;
  }>(parts[1]);
  if (header.alg !== "RS256" || !header.kid) throw new HttpError(401, "invalid_token", "Unsupported Apple token.");

  let keys = await appleKeys();
  let jwk = keys.find((k) => k.kid === header.kid);
  if (!jwk) {
    keys = await appleKeys(true);
    jwk = keys.find((k) => k.kid === header.kid);
  }
  if (!jwk) throw new HttpError(401, "invalid_token", "Apple token was signed with an unknown key.");

  const key = await crypto.subtle.importKey("jwk", jwk, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
  const valid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    base64urlDecode(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!valid) throw new HttpError(401, "invalid_token", "Apple token signature is invalid.");
  if (payload.iss !== "https://appleid.apple.com") throw new HttpError(401, "invalid_token", "Apple token issuer is invalid.");
  const aud = Array.isArray(payload.aud) ? payload.aud : [payload.aud];
  if (!aud.some((a) => typeof a === "string" && audiences.includes(a))) throw new HttpError(401, "invalid_token", "Apple token was issued for a different app.");
  const now = Math.floor(Date.now() / 1000);
  if (typeof payload.exp !== "number" || payload.exp < now - 30) throw new HttpError(401, "token_expired", "Apple sign-in expired. Please try again.");
  if (!payload.sub) throw new HttpError(401, "invalid_token", "Apple token has no subject.");
  if (rawNonce !== null) {
    const expected = await sha256Hex(rawNonce);
    if (payload.nonce !== expected) throw new HttpError(401, "invalid_nonce", "Apple sign-in couldn't be verified. Please try again.");
  }
  const truthy = (v: unknown) => v === true || v === "true";
  return {
    sub: payload.sub,
    email: typeof payload.email === "string" ? payload.email.toLowerCase() : null,
    emailVerified: truthy(payload.email_verified),
    isPrivateEmail: truthy(payload.is_private_email),
  };
}
