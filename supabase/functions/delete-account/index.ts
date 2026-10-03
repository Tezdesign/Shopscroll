// Decision record: docs/specs/buyer/0004-clerk-authentication/index.md
//
// Deletes the calling buyer's own account (spec 0004, AC-8): the Clerk user
// first, then their rows here. The app's Delete account row calls this.
//
// Why a function and not `ClerkAuthState.deleteUser()`: that path is broken
// in `clerk_auth` 0.0.18-beta, the newest release. `Api._delete` clears the
// token cache — client token, session id and client id — and only then builds
// its headers, which attach `Authorization` `if (hasClientToken)`. The
// request goes out unauthenticated and Clerk answers `401 signed_out`. See
// `apps/buyer/lib/features/profile/AGENTS.md`. Deleting from a trusted server is where
// this belongs anyway: the secret key never reaches a device, and the Clerk
// user and the Supabase rows go in one call rather than depending on the
// `user.deleted` webhook having been registered.
//
// Secrets, both set by hand and never sent to the client:
//   supabase secrets set CLERK_SECRET_KEY=sk_...
//   supabase secrets set CLERK_ISSUER=https://<your-app>.clerk.accounts.dev
//
// CLERK_ISSUER is pinned rather than read from the token: taking the issuer
// from an unverified token and then fetching that issuer's keys to verify it
// would prove nothing, since an attacker would supply both.

import { createRemoteJWKSet, jwtVerify } from "npm:jose@5.9.6";
import {
  deleteUserData,
  serviceRoleClient,
} from "../_shared/delete_user_data.ts";

const issuer = Deno.env.get("CLERK_ISSUER");
const jwks = issuer
  ? createRemoteJWKSet(new URL(`${issuer}/.well-known/jwks.json`))
  : null;

const json = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

/// The Clerk user id the request proves it is, or null when it proves
/// nothing. Verification is this function's own: it never trusts a `sub` the
/// caller simply asserts, and it fails closed on any error.
async function callerUserId(req: Request): Promise<string | null> {
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

/// Deletes the Clerk user. Treats "already gone" as success so a retry after
/// a partial failure still cleans up the rows.
async function deleteClerkUser(
  userId: string,
  secretKey: string,
): Promise<Error | null> {
  const response = await fetch(`https://api.clerk.com/v1/users/${userId}`, {
    method: "DELETE",
    headers: { Authorization: `Bearer ${secretKey}` },
  });

  if (response.ok || response.status === 404) return null;
  return new Error(
    `Clerk refused the deletion: ${response.status} ${await response.text()}`,
  );
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const secretKey = Deno.env.get("CLERK_SECRET_KEY");
  if (!secretKey || !issuer) {
    console.error("delete-account: CLERK_SECRET_KEY or CLERK_ISSUER not set");
    return json({ error: "Account deletion is not configured" }, 500);
  }

  const userId = await callerUserId(req);
  if (!userId) return json({ error: "Not signed in" }, 401);

  // Clerk first. If the rows fail afterwards the account is still gone and a
  // retry (or the `user.deleted` webhook) finishes the cleanup; doing it the
  // other way round could strip someone's data and leave them signed in.
  const clerkError = await deleteClerkUser(userId, secretKey);
  if (clerkError) {
    console.error("delete-account:", clerkError);
    return json({ error: "Could not delete the account" }, 502);
  }

  const dataError = await deleteUserData(serviceRoleClient(), userId);
  if (dataError) {
    // The account is gone, so the person is deleted either way. Say so
    // rather than reporting a failure that would invite a pointless retry.
    console.error("delete-account: rows left behind:", dataError);
  }

  return json({ deleted: true }, 200);
});
