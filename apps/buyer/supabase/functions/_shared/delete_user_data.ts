// Decision record: docs/specs/buyer/0004-clerk-authentication/index.md
//
// Removing one identity's rows from Supabase (spec 0004, AC-8): cart, likes,
// saves and profile go; order history stays, because an order is a financial
// record of a sale that happened, not personal data the buyer owns outright.
//
// Two callers share this, and must not drift apart: `clerk-webhook`, for a
// deletion started anywhere else (the Clerk dashboard, the Backend API), and
// `delete-account`, for the buyer deleting their own account in the app.
//
// Writes with the service role key, which bypasses RLS by design: this is the
// one place in the app allowed to delete another identity's data outright,
// and only ever an identity whose deletion has already been proven by the
// caller (a verified Svix signature, or a verified Clerk session token).

import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2.45.0";

/// A service role client. `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are
/// injected by the Edge Function runtime; neither needs manual setup.
export function serviceRoleClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}

/// Deletes everything this app holds for `userId` except their orders.
///
/// Idempotent: deleting rows that are already gone is not an error, so a
/// retried webhook or a second attempt after a partial failure is safe.
/// Returns the first error encountered, or null when everything went.
export async function deleteUserData(
  supabase: SupabaseClient,
  userId: string,
): Promise<Error | null> {
  const results = await Promise.all([
    supabase.from("cart_items").delete().eq("user_id", userId),
    supabase.from("reel_likes").delete().eq("user_id", userId),
    supabase.from("reel_saves").delete().eq("user_id", userId),
    supabase.from("product_saves").delete().eq("user_id", userId),
    supabase.from("user_profiles").delete().eq("id", userId),
  ]);

  const failure = results.find((result) => result.error);
  return failure?.error ? new Error(failure.error.message) : null;
}
