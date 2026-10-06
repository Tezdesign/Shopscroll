// Decision record: docs/specs/_root/0016-seller-application-admin-email/index.md
// (AC-4 to AC-8, AC-11, AC-13)
//
// The service behind the review page that the admin's email links to. The page
// is a static page on Cloudflare Pages (`web/admin-review/`), because Edge
// Functions cannot show an HTML page on their default address.
//
// POST { "token": "<from the link>", "action": "view" | "approve" | "reject", "reason"?: "<for reject>" }
//   view     200 { application, photos: [{ kind, url, image }] }  (links last 5 minutes)
//   approve  200 { status: "approved" }
//   reject   200 { status: "rejected" }
//   404 invalid_link (unknown, expired or used token, all the same) · 409 already_decided,
//   already_seller, username_taken · 422 reason_required · 400 bad_request · 500 failed
//
// Answers the CORS preflight (OPTIONS) before any token check, and puts the CORS
// headers on every answer, errors included, only for the exact origin of
// REVIEW_PAGE_URL. Deploy with `--no-verify-jwt`: the token is the credential.
// Secrets (supabase secrets set ...):
//   REVIEW_PAGE_URL   the review page address, the same one `notify-admin-application` uses
// The service role key, which the runtime injects, reads the application, signs the
// photo links and calls `decide_application_with_token`. The logic and its tests are
// in `_shared/review_application.ts`. Logs hold short codes only.

import { hashToken } from "../_shared/admin_email.ts";
import { loadApplicationDetails } from "../_shared/application_loader.ts";
import { serviceRoleClient } from "../_shared/delete_user_data.ts";
import { handleReview, type ReviewDeps } from "../_shared/review_application.ts";

const MAX_BODY_BYTES = 4096;

function depsFor(): ReviewDeps {
  const supabase = serviceRoleClient();
  return {
    async findToken(tokenHash) {
      const { data, error } = await supabase
        .from("application_review_tokens")
        .select("application_id, used_at, expires_at")
        .eq("token_hash", tokenHash)
        .maybeSingle();
      if (error) throw new Error(error.message);
      return data
        ? { applicationId: data.application_id, usedAt: data.used_at, expiresAt: data.expires_at }
        : null;
    },
    load: (id) => loadApplicationDetails(supabase, id),
    async signedUrl(bucket, path, seconds) {
      const { data, error } = await supabase.storage.from(bucket).createSignedUrl(path, seconds);
      return error ? null : data.signedUrl;
    },
    async decide(tokenHash, action, reason) {
      const { data, error } = await supabase.rpc("decide_application_with_token", {
        p_token_hash: tokenHash,
        p_action: action,
        p_reason: reason,
      });
      if (error) throw new Error(error.message);
      return data as string;
    },
    now: () => new Date(),
  };
}

Deno.serve(async (req) => {
  const reviewPageUrl = Deno.env.get("REVIEW_PAGE_URL");
  if (!reviewPageUrl) {
    console.error("review-application: REVIEW_PAGE_URL not set");
    return new Response(JSON.stringify({ error: "not_configured" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
  const allowedOrigin = new URL(reviewPageUrl).origin;

  // The browser only reads an answer that names its own origin, so any other
  // origin gets no allow header and the page cannot see the answer.
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "Vary": "Origin",
  };
  if (req.headers.get("Origin") === allowedOrigin) {
    headers["Access-Control-Allow-Origin"] = allowedOrigin;
    headers["Access-Control-Allow-Methods"] = "POST, OPTIONS";
    headers["Access-Control-Allow-Headers"] = "Content-Type";
    headers["Access-Control-Max-Age"] = "600";
  }
  const answer = (body: unknown, status: number) =>
    new Response(JSON.stringify(body), { status, headers });

  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers });
  if (req.method !== "POST") return answer({ error: "bad_request" }, 405);

  const text = await req.text();
  if (text.length > MAX_BODY_BYTES) return answer({ error: "bad_request" }, 400);
  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch {
    return answer({ error: "bad_request" }, 400);
  }

  const result = await handleReview(depsFor(), body);
  if (result.status >= 500) {
    console.error(`review-application: failed (${result.body.error})`);
  } else if (result.status === 404) {
    // Only the hash prefix, never the token, to see probing without keeping secrets.
    const token = (body as { token?: unknown })?.token;
    console.log(
      `review-application: invalid_link ${typeof token === "string" ? (await hashToken(token)).slice(0, 8) : "-"}`,
    );
  }
  return answer(result.body, result.status);
});
