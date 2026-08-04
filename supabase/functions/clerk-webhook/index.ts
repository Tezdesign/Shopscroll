// Decision record: docs/specs/0004-clerk-authentication/index.md
//
// Handles Clerk's `user.deleted` webhook: removes that person's cart,
// likes, saves, and profile, but keeps their order history (spec 0004,
// AC-8). Verifies the webhook's Svix signature before doing anything, using
// CLERK_WEBHOOK_SIGNING_SECRET, an Edge Function secret set manually
// (`supabase secrets set CLERK_WEBHOOK_SIGNING_SECRET=whsec_...`), never
// sent to the client. SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are
// injected automatically by the Edge Function runtime, no manual setup
// needed for those two.
//
// Writes with the service role key, which bypasses RLS by design: this is
// the one place in the app allowed to delete another identity's data
// outright, and only ever the identity Clerk itself just told us was
// deleted (proven by the verified signature above, not by anything the
// request itself claims).

import { Webhook } from "npm:svix@1.15.0";
import { createClient } from "npm:@supabase/supabase-js@2.45.0";

interface ClerkUserDeletedEvent {
  type: string;
  data: { id?: string };
}

Deno.serve(async (req) => {
  const signingSecret = Deno.env.get("CLERK_WEBHOOK_SIGNING_SECRET");
  if (!signingSecret) {
    return new Response("Webhook signing secret not configured", {
      status: 500,
    });
  }

  const payload = await req.text();
  const svixHeaders = {
    "svix-id": req.headers.get("svix-id") ?? "",
    "svix-timestamp": req.headers.get("svix-timestamp") ?? "",
    "svix-signature": req.headers.get("svix-signature") ?? "",
  };

  let event: ClerkUserDeletedEvent;
  try {
    const webhook = new Webhook(signingSecret);
    event = webhook.verify(payload, svixHeaders) as ClerkUserDeletedEvent;
  } catch {
    return new Response("Invalid signature", { status: 400 });
  }

  if (event.type !== "user.deleted") {
    // Ignore every other event type; still 200 so Clerk does not retry.
    return new Response("Ignored", { status: 200 });
  }

  const deletedUserId = event.data.id;
  if (!deletedUserId) {
    return new Response("Missing user id", { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const [cartResult, likesResult, savesResult, profileResult] =
    await Promise.all([
      supabase.from("cart_items").delete().eq("user_id", deletedUserId),
      supabase.from("reel_likes").delete().eq("user_id", deletedUserId),
      supabase.from("reel_saves").delete().eq("user_id", deletedUserId),
      supabase.from("user_profiles").delete().eq("id", deletedUserId),
    ]);

  const failure = [cartResult, likesResult, savesResult, profileResult].find(
    (result) => result.error,
  );
  if (failure?.error) {
    console.error("clerk-webhook cleanup failed:", failure.error);
    return new Response("Cleanup failed", { status: 500 });
  }

  return new Response("OK", { status: 200 });
});
