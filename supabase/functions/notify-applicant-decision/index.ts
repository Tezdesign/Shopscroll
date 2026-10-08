// Decision record: docs/specs/_root/0017-applicant-decision-email/index.md
// (AC-1, AC-2, AC-6, AC-13)
//
// Emails the applicant when a seller application is approved or rejected,
// through Mailjet. The database calls it: an after update trigger posts the
// application id when the status leaves `reviewing`, and the retry job posts
// again for decisions still unsent (migration 0012). Nobody else should: it
// refuses a call without the shared secret.
//
// POST { "application_id": "<uuid>" }, header x-webhook-secret
//   200 { sent: true | false, reason? }
//   400 bad body · 401 bad secret · 500 not_configured
//
// Deploy with `--no-verify-jwt` (the database calls it with the shared secret,
// not a user token). It uses the secrets `notify-admin-application` already has:
//   ADMIN_NOTIFY_SECRET    the shared secret, also saved in Vault as admin_notify_secret
//   MAILJET_API_KEY, MAILJET_API_SECRET, MAILJET_SENDER_EMAIL
//   ADMIN_EMAIL            where replies go
// The Vault entry `applicant_notify_url` (this function's address) is new. The
// service role key, which the runtime injects, reads the row and writes the
// result. The logic and its tests are in `_shared/applicant_email.ts`. Logs hold
// ids and short codes only.

import { secretsMatch, sendWithMailjet } from "../_shared/admin_email.ts";
import {
  type ApplicantNotifyDeps,
  notifyApplicant,
} from "../_shared/applicant_email.ts";
import { serviceRoleClient } from "../_shared/delete_user_data.ts";

const json = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function depsFor(apiKey: string, apiSecret: string): ApplicantNotifyDeps {
  const supabase = serviceRoleClient();
  return {
    // The recipient and the status come straight from the row, never through a
    // profile or `application_loader.ts`.
    async load(id) {
      const { data: row, error } = await supabase
        .from("seller_applications")
        .select(
          "id, origin, status, applicant_notified_at, store_name, " +
            "rejection_reason, applicant_email, contact_email",
        )
        .eq("id", id)
        .maybeSingle();
      if (error) throw new Error(error.message);
      if (!row) return null;
      return {
        id: row.id,
        origin: row.origin,
        status: row.status,
        applicantNotifiedAt: row.applicant_notified_at,
        storeName: row.store_name,
        rejectionReason: row.rejection_reason,
        applicantEmail: row.applicant_email,
        contactEmail: row.contact_email,
      };
    },
    async claim(id) {
      const { data, error } = await supabase.rpc("claim_applicant_notification", {
        p_id: id,
      });
      if (error) throw new Error(error.message);
      return data === true;
    },
    async markNotified(id) {
      const { error } = await supabase
        .from("seller_applications")
        .update({
          applicant_notified_at: new Date().toISOString(),
          applicant_notify_error: null,
        })
        .eq("id", id);
      if (error) throw new Error(error.message);
    },
    async markError(id, code) {
      await supabase
        .from("seller_applications")
        .update({ applicant_notify_error: code })
        .eq("id", id);
    },
    send: (message) => sendWithMailjet(fetch, apiKey, apiSecret, message),
  };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const secret = Deno.env.get("ADMIN_NOTIFY_SECRET");
  const apiKey = Deno.env.get("MAILJET_API_KEY");
  const apiSecret = Deno.env.get("MAILJET_API_SECRET");
  const sender = Deno.env.get("MAILJET_SENDER_EMAIL");
  const admin = Deno.env.get("ADMIN_EMAIL");
  if (!secret || !apiKey || !apiSecret || !sender || !admin) {
    console.error("notify-applicant-decision: not configured");
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

  const result = await notifyApplicant(
    depsFor(apiKey, apiSecret),
    { sender, admin },
    applicationId,
  );
  console.log(
    `notify-applicant-decision: ${applicationId} sent=${result.sent} ${result.reason ?? ""}`,
  );
  return json(result, 200);
});
