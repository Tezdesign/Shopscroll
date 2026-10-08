// Decision record: docs/specs/buyer/0004-clerk-authentication/index.md
//
// Removing one identity's rows from Supabase (spec 0004, AC-8): cart, likes,
// saves and profile go; order history stays, because an order is a financial
// record of a sale that happened, not personal data the buyer owns outright.
// Seller applications go with the profile (they cascade), and the photos that
// came with them are removed from both Storage buckets (spec 0013, AC-11).
// Visitor applications the account owns (spec 0014, AC-14) are removed first,
// with their files, because they do not cascade. Visitor applications that are
// only attached to it belong to somebody else and are detached, not deleted.
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
import {
  deleteUserFiles,
  deleteVisitorApplications,
  type VisitorApplicationRows,
} from "./delete_user_files.ts";

/// A service role client. `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are
/// injected by the Edge Function runtime; neither needs manual setup.
export function serviceRoleClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}

/// The visitor applications of one account, read, deleted and detached with the
/// service role. The id goes into a PostgREST filter string, so anything but the
/// characters a Clerk id has is refused rather than escaped.
function visitorApplicationRows(supabase: SupabaseClient): VisitorApplicationRows {
  return {
    async list(userId) {
      if (!/^[A-Za-z0-9_-]+$/.test(userId)) {
        throw new Error("invalid user id for application cleanup");
      }
      const { data, error } = await supabase
        .from("seller_applications")
        .select("id, id_document_path, business_document_path, logo_path")
        .eq("origin", "visitor")
        .eq("applicant_id", userId);
      if (error) throw new Error(error.message);
      return (data ?? []).map((row) => ({
        id: row.id as string,
        paths: [row.id_document_path, row.business_document_path, row.logo_path],
      }));
    },
    async remove(ids) {
      const { error } = await supabase
        .from("seller_applications")
        .delete()
        .in("id", ids);
      if (error) throw new Error(error.message);
    },
    async detach(userId) {
      // Two statements: a reviewing row can refuse to detach (its session sent
      // another reviewing row), and that must not undo the others. A refusal
      // leaves that one row attached to the deleted id, which hurts nobody.
      for (const reviewing of [false, true]) {
        const query = supabase
          .from("seller_applications")
          .update({ bound_account_id: null })
          .eq("bound_account_id", userId)
          .is("applicant_id", null);
        const { error } = await (reviewing
          ? query.eq("status", "reviewing")
          : query.neq("status", "reviewing"));
        if (error && !(reviewing && error.code === "23505")) {
          throw new Error(error.message);
        }
      }
    },
  };
}

/// Deletes everything this app holds for `userId` except their orders: the
/// rows, and every file they uploaded for a seller application.
///
/// Idempotent: deleting rows and files that are already gone is not an error,
/// so a retried webhook or a second attempt after a partial failure is safe.
/// The visitor applications go first and alone (AC-14): their paths come from
/// rows, and the profile delete below cascades some of those rows away. If that
/// first step fails nothing else runs, so a retry still has the paths. After it,
/// the files and the rows are attempted independently, so a failure in one does
/// not leave the other behind. Returns the first error encountered, or null when
/// everything went.
export async function deleteUserData(
  supabase: SupabaseClient,
  userId: string,
): Promise<Error | null> {
  const visitorError = await deleteVisitorApplications(
    supabase.storage,
    visitorApplicationRows(supabase),
    userId,
  );
  if (visitorError) return visitorError;

  const [filesError, ...results] = await Promise.all([
    deleteUserFiles(supabase.storage, userId),
    supabase.from("cart_items").delete().eq("user_id", userId),
    supabase.from("reel_likes").delete().eq("user_id", userId),
    supabase.from("reel_saves").delete().eq("user_id", userId),
    supabase.from("product_saves").delete().eq("user_id", userId),
    supabase.from("user_profiles").delete().eq("id", userId),
  ]);

  if (filesError) return filesError;
  const failure = results.find((result) => result.error);
  return failure?.error ? new Error(failure.error.message) : null;
}
