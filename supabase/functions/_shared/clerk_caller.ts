// Decision record: docs/specs/_root/0014-shared-login-seller-area/index.md
//
// Proves which Clerk user an Edge Function request comes from, shared by
// `delete-account` and `claim-seller-application` so the one security sensitive
// check cannot drift between them. The verification is this module's own: it
// never trusts a `sub` the caller simply asserts, and it fails closed on any
// error.
//
// CLERK_ISSUER is pinned rather than read from the token: taking the issuer
// from an unverified token and then fetching that issuer's keys to verify it
// would prove nothing, since an attacker would supply both.

import { createRemoteJWKSet, jwtVerify } from "npm:jose@5.9.6";

export const issuer = Deno.env.get("CLERK_ISSUER");
const jwks = issuer
  ? createRemoteJWKSet(new URL(`${issuer}/.well-known/jwks.json`))
  : null;

/// The Clerk user id the request proves it is, or null when it proves nothing.
export async function callerUserId(req: Request): Promise<string | null> {
  if (!jwks) return null;

  const header = req.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!token) return null;

  try {
    const { payload } = await jwtVerify(token, jwks, { issuer });
    return typeof payload.sub === "string" && payload.sub.length > 0
      ? payload.sub
      : null;
  } catch {
    return null;
  }
}
