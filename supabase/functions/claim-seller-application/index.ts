// Decision record: docs/specs/_root/0014-shared-login-seller-area/index.md
// (AC-12, AC-13)
//
// The app calls this after every real sign in, when it launches or resumes with a
// signed in buyer, and when the Seller application screen opens or is refreshed.
// It does two things in order. First the attach: a visitor application whose typed
// email or phone Clerk has verified for this account is attached to it. Then the
// claim: if an admin has approved an application attached to the account, the
// function turns it into a seller. Answers `{ "claimed": true }` or
// `{ "claimed": false }`. A refusal (already a seller, username taken, nothing to
// claim) is a plain `claimed: false` and never an error, so the sign in is never
// blocked by it. A failed attach (Clerk down, database error) is logged as a short
// code and never blocks the claim of a row that is already attached; it answers
// 500 only when the attach failed and nothing was claimed, and the app asks again
// later.
//
// Verifies the caller's Clerk session token itself (`_shared/clerk_caller.ts`),
// so deploy it with `--no-verify-jwt`, like `delete-account`. Both secrets are
// the ones `delete-account` already uses (the secret key is only used to read the
// caller's verified email addresses and phone numbers, and is never returned):
//   supabase secrets set CLERK_ISSUER=https://<your-app>.clerk.accounts.dev
//   supabase secrets set CLERK_SECRET_KEY=sk_...
// The service role key, which the runtime injects, is the only thing that
// touches the database.

import { callerUserId, issuer } from "../_shared/clerk_caller.ts";
import { claimSellerApplication } from "../_shared/claim_seller_application.ts";
import { verifiedContacts } from "../_shared/clerk_contacts.ts";
import { serviceRoleClient } from "../_shared/delete_user_data.ts";

const clerkSecretKey = Deno.env.get("CLERK_SECRET_KEY");

const json = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }
  if (!issuer) {
    console.error("claim-seller-application: CLERK_ISSUER not set");
    return json({ error: "Claiming is not configured" }, 500);
  }

  const userId = await callerUserId(req);
  if (!userId) return json({ error: "Not signed in" }, 401);

  try {
    const result = await claimSellerApplication(
      serviceRoleClient(),
      userId,
      clerkSecretKey
        ? () => verifiedContacts(fetch, clerkSecretKey, userId)
        : undefined,
    );
    if (result.reason) {
      console.log("claim-seller-application: not claimed:", result.reason);
    }
    return json({ claimed: result.claimed }, 200);
  } catch (error) {
    console.error("claim-seller-application:", error);
    return json({ error: "Could not claim the application" }, 500);
  }
});
