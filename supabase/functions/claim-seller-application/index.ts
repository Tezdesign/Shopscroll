// Decision record: docs/specs/_root/0014-shared-login-seller-area/index.md
// (AC-13)
//
// The app calls this after every real sign in, when it launches or resumes with
// a signed in buyer, and when the Seller application screen opens: if an admin
// approved a visitor application that was attached to this account, it makes
// the account a seller. Answers `{ "claimed": true }` or `{ "claimed": false }`.
// A refusal (already a seller, username taken, nothing to claim) is a plain
// `claimed: false` and never an error, so the sign in is never blocked by it.
//
// Verifies the caller's Clerk session token itself (`_shared/clerk_caller.ts`),
// so deploy it with `--no-verify-jwt`, like `delete-account`. The one secret it
// needs is the issuer `delete-account` already uses (the Clerk secret key is not
// read here):
//   supabase secrets set CLERK_ISSUER=https://<your-app>.clerk.accounts.dev
// The service role key, which the runtime injects, is the only thing that
// touches the database.

import { callerUserId, issuer } from "../_shared/clerk_caller.ts";
import { claimSellerApplication } from "../_shared/claim_seller_application.ts";
import { serviceRoleClient } from "../_shared/delete_user_data.ts";

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
    const result = await claimSellerApplication(serviceRoleClient(), userId);
    if (result.reason) {
      console.log("claim-seller-application: not claimed:", result.reason);
    }
    return json({ claimed: result.claimed }, 200);
  } catch (error) {
    console.error("claim-seller-application:", error);
    return json({ error: "Could not claim the application" }, 500);
  }
});
