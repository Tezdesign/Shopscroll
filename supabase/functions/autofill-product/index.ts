// Decision record: docs/specs/_root/0015-seller-product-creation/index.md
// (AC-13, build plan task 10)
//
// "Fill from photos". The seller's app calls it with the id of their draft (or
// of a product they own) and gets back a SUGGESTION for the title, description,
// category, colors and material, made by Claude from the product photos. The
// app shows it and the seller decides; this function never writes to `products`
// or `product_drafts`.
//
// POST { "draft_id": "<uuid>" }  or  { "product_id": "<uuid>" }
//   200 { title, description, category, colors[], material, remaining }
//   400 bad_request · 401 no session · 403 not_seller · 404 not_found
//   422 no_photos · 429 quota_exceeded (remaining 0)
//   502 model_failed / bad_answer · 504 timeout
//
// Verifies the caller's Clerk session token itself (`_shared/clerk_caller.ts`),
// so deploy it with `--no-verify-jwt`, like `claim-seller-application`.
// Secrets and settings (supabase secrets set ...):
//   ANTHROPIC_API_KEY      the Claude API key (required)
//   CLERK_ISSUER           already set for the other functions
//   AUTOFILL_MODEL         optional, default claude-sonnet-5-5
//   AUTOFILL_DAILY_LIMIT   optional, default 30 runs a day per seller
// The service role key, which the runtime injects, reads the draft and the
// photos and counts the run. The logic and its tests are in
// `_shared/autofill_product.ts`.

// Pin the version after the first deploy (not run here: no Deno on this machine).
import Anthropic from "npm:@anthropic-ai/sdk";
import { encodeBase64 } from "jsr:@std/encoding@^1.0.5/base64";
import { callerUserId, issuer } from "../_shared/clerk_caller.ts";
import { serviceRoleClient } from "../_shared/delete_user_data.ts";
import {
  type AutofillDeps,
  autofillProduct,
  buildSystemPrompt,
  DEFAULT_DAILY_LIMIT,
  PHOTO_BUCKET,
  type PhotoBytes,
  SUGGESTION_SCHEMA,
} from "../_shared/autofill_product.ts";

const json = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const model = Deno.env.get("AUTOFILL_MODEL") ?? "claude-sonnet-5-5";
const dailyLimit = Number(Deno.env.get("AUTOFILL_DAILY_LIMIT") ?? DEFAULT_DAILY_LIMIT);

function depsFor(): AutofillDeps {
  const supabase = serviceRoleClient();
  // No retries: a timeout must not turn into three paid attempts.
  const anthropic = new Anthropic({
    apiKey: Deno.env.get("ANTHROPIC_API_KEY"),
    maxRetries: 0,
  });

  return {
    async isSeller(userId) {
      const { data } = await supabase
        .from("user_profiles")
        .select("role")
        .eq("id", userId)
        .maybeSingle();
      return data?.role === "seller";
    },

    async loadPhotoPaths(userId, target) {
      if (target.draftId) {
        const { data } = await supabase
          .from("product_drafts")
          .select("payload")
          .eq("id", target.draftId)
          .eq("store_id", userId)
          .maybeSingle();
        if (!data) return null;
        const photos = (data.payload as { photos?: unknown })?.photos;
        return Array.isArray(photos)
          ? photos.filter((p): p is string => typeof p === "string")
          : [];
      }
      const { data } = await supabase
        .from("products")
        .select("image_urls")
        .eq("id", target.productId!)
        .eq("store_id", userId)
        .maybeSingle();
      if (!data) return null;
      const prefix = `${PHOTO_BUCKET}/`;
      return (data.image_urls as string[] ?? [])
        .filter((p) => p.startsWith(prefix))
        .map((p) => p.slice(prefix.length));
    },

    async categories() {
      const { data } = await supabase
        .from("product_categories")
        .select("slug")
        .order("position");
      return (data ?? []).map((r: { slug: string }) => r.slug);
    },

    async takeRun(userId, limit) {
      const { data, error } = await supabase.rpc("take_autofill_run", {
        p_user: userId,
        p_limit: limit,
      });
      if (error) throw new Error(`take_autofill_run: ${error.message}`);
      return data as number;
    },

    async downloadPhoto(path): Promise<PhotoBytes | null> {
      const { data, error } = await supabase.storage.from(PHOTO_BUCKET).download(path);
      if (error || !data) return null;
      return { bytes: new Uint8Array(await data.arrayBuffer()), mediaType: "image/jpeg" };
    },

    async callModel(photos, categories, signal) {
      const response = await anthropic.messages.create(
        {
          model,
          max_tokens: 2000,
          system: buildSystemPrompt(categories),
          // Low effort is enough to describe a product, and the answer is held
          // to a JSON schema so there is nothing to scrape out of prose.
          output_config: {
            effort: "low",
            format: { type: "json_schema", schema: SUGGESTION_SCHEMA },
          },
          messages: [
            {
              role: "user",
              content: [
                ...photos.map((p) => ({
                  type: "image" as const,
                  source: {
                    type: "base64" as const,
                    media_type: p.mediaType,
                    data: encodeBase64(p.bytes),
                  },
                })),
                { type: "text" as const, text: "Write the listing for this product." },
              ],
            },
          ],
        },
        { signal },
      );
      if (response.stop_reason === "refusal") throw new Error("model refused");
      for (const block of response.content) {
        if (block.type === "text") return block.text;
      }
      throw new Error("model returned no text");
    },
  };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  if (!issuer || !Deno.env.get("ANTHROPIC_API_KEY")) {
    console.error("autofill-product: CLERK_ISSUER or ANTHROPIC_API_KEY not set");
    return json({ error: "Not configured" }, 500);
  }

  const userId = await callerUserId(req);
  if (!userId) return json({ error: "Not signed in" }, 401);

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad_request" }, 400);
  }

  try {
    const result = await autofillProduct(depsFor(), userId, body, { limit: dailyLimit });
    return json(result.body, result.status);
  } catch (error) {
    console.error("autofill-product:", error);
    return json({ error: "Could not fill from photos" }, 500);
  }
});
