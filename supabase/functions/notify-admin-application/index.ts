// Decision record: docs/specs/_root/0016-seller-application-admin-email/index.md
// (AC-1, AC-9, AC-10, AC-11)
//
// Emails the admin about one new seller application through Mailjet. The
// database calls it: an after insert trigger posts the application id, and the
// retry job posts again for applications still unsent (migration 0011). Nobody
// else should: it refuses a call without the shared secret.
//
// POST { "application_id": "<uuid>" }, header x-webhook-secret
//   200 { sent: true | false, reason? }
//   400 bad body · 401 bad secret · 500 not_configured
//
// Deploy with `--no-verify-jwt` (the database calls it with the shared secret,
// not a user token). Secrets (supabase secrets set ...):
//   ADMIN_NOTIFY_SECRET    the shared secret, also saved in Vault as admin_notify_secret
//   MAILJET_API_KEY        Mailjet API key
//   MAILJET_API_SECRET     Mailjet API secret
//   MAILJET_SENDER_EMAIL   a sender address already verified in Mailjet
//   ADMIN_EMAIL            who receives the emails
//   REVIEW_PAGE_URL        the review page address (Cloudflare Pages)
// The service role key, which the runtime injects, reads the application and
// writes the token and the result. The logic and its tests are in
// `_shared/admin_email.ts`. Logs hold ids and short codes only.

import {
  notifyAdmin,
  type NotifyDeps,
  secretsMatch,
  sendWithMailjet,
} from "../_shared/admin_email.ts";
import { loadApplicationDetails } from "../_shared/application_loader.ts";
import { serviceRoleClient } from "../_shared/delete_user_data.ts";

const json = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function depsFor(apiKey: string, apiSecret: string): NotifyDeps {
  const supabase = serviceRoleClient();
  return {
    load: (id) => loadApplicationDetails(supabase, id),
    async claim(id) {
      const { data, error } = await supabase.rpc("claim_admin_notification", {
        p_id: id,
      });
      if (error) throw new Error(error.message);
      return data === true;
    },
    async saveToken(applicationId, tokenHash, expiresAt) {
      const { error } = await supabase.from("application_review_tokens").insert({
        application_id: applicationId,
        token_hash: tokenHash,
        expires_at: expiresAt.toISOString(),
      });
      if (error) throw new Error(error.message);
    },
    async markNotified(id) {
      const { error } = await supabase
        .from("seller_applications")
        .update({ admin_notified_at: new Date().toISOString(), admin_notify_error: null })
        .eq("id", id);
      if (error) throw new Error(error.message);
    },
    async markError(id, code) {
      await supabase
        .from("seller_applications")
        .update({ admin_notify_error: code })
        .eq("id", id);
    },
    send: (message) => sendWithMailjet(fetch, apiKey, apiSecret, message),
    now: () => new Date(),
  };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const secret = Deno.env.get("ADMIN_NOTIFY_SECRET");
  const apiKey = Deno.env.get("MAILJET_API_KEY");
  const apiSecret = Deno.env.get("MAILJET_API_SECRET");
  const sender = Deno.env.get("MAILJET_SENDER_EMAIL");
  const admin = Deno.env.get("ADMIN_EMAIL");
  const reviewPageUrl = Deno.env.get("REVIEW_PAGE_URL");
  if (!secret || !apiKey || !apiSecret || !sender || !admin || !reviewPageUrl) {
    console.error("notify-admin-application: not configured");
    return json({ error: "not_configured" }, 500);
  }

  const given = req.headers.get("x-webhook-secret") ?? "";
  if (!(await secretsMatch(given, secret))) {
    return json({ error: "Not allowed" }, 401);
  }

  let applicationId: unknown;
  try {
    applicationId = (await req.json())?.application_id;
  } catch {
    return json({ error: "bad_request" }, 400);
  }
  if (typeof applicationId !== "string" || !UUID.test(applicationId)) {
    return json({ error: "bad_request" }, 400);
  }

  const result = await notifyAdmin(
    depsFor(apiKey, apiSecret),
    { reviewPageUrl, sender, admin },
    applicationId,
  );
  console.log(
    `notify-admin-application: ${applicationId} sent=${result.sent} ${result.reason ?? ""}`,
  );
  return json(result, 200);
});
