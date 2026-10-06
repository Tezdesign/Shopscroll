// Run with `deno test supabase/functions/_shared/review_application_test.ts`.
// Needs no network: the database and Storage are fakes. It uses only `Deno.test`
// and `node:assert`, so Node 22 can run it too.

import assert from "node:assert/strict";
import { hashToken } from "./admin_email.ts";
import type { ApplicationDetails } from "./application_loader.ts";
import {
  handleReview,
  PHOTO_LINK_SECONDS,
  type ReviewDeps,
  type TokenRow,
} from "./review_application.ts";

const TOKEN = "T".repeat(43);
const APP = "00000000-0000-0000-0000-0000000000a1";
const NOW = new Date("2026-10-05T10:00:00Z");

function details(overrides: Partial<ApplicationDetails> = {}): ApplicationDetails {
  return {
    id: APP,
    origin: "visitor",
    status: "reviewing",
    adminNotifiedAt: null,
    storeName: "Warda Shop",
    username: "warda",
    location: "Tunis",
    bio: null,
    websiteUrl: null,
    contactPhone: null,
    contactEmail: null,
    createdAt: "2026-10-05T09:00:00Z",
    applicantName: "Visitor One",
    applicantEmail: "v@example.com",
    applicantPhone: "+21612345678",
    idDocumentPath: "anon/a1/id-1.jpg",
    businessDocumentPath: "anon/a1/business-1.pdf",
    logoPath: "anon/a1/logo-1.png",
    ...overrides,
  };
}

class Fake implements ReviewDeps {
  hash = "";
  token: TokenRow | null = {
    applicationId: APP,
    usedAt: null,
    expiresAt: "2026-10-12T10:00:00Z",
  };
  app: ApplicationDetails | null = details();
  decision: string | Error = "approved";
  signed: { bucket: string; path: string; seconds: number }[] = [];
  decided: { hash: string; action: string; reason: string | null }[] = [];
  missingFiles = new Set<string>();

  async findToken(tokenHash: string) {
    this.hash = tokenHash;
    return this.token;
  }
  async load(_id: string) {
    return this.app;
  }
  async signedUrl(bucket: string, path: string, seconds: number) {
    this.signed.push({ bucket, path, seconds });
    return this.missingFiles.has(path) ? null : `https://files.example/${bucket}/${path}?sig=1`;
  }
  async decide(hash: string, action: "approve" | "reject", reason: string | null) {
    this.decided.push({ hash, action, reason });
    if (this.decision instanceof Error) throw this.decision;
    return this.decision;
  }
  now() {
    return NOW;
  }
}

Deno.test("view shows the details and fresh short links to the photos, and decides nothing", async () => {
  const fake = new Fake();

  const answer = await handleReview(fake, { token: TOKEN, action: "view" });

  assert.equal(answer.status, 200);
  const body = answer.body as { application: Record<string, unknown>; photos: { kind: string; url: string; image: boolean }[] };
  assert.equal(body.application.storeName, "Warda Shop");
  assert.equal(body.application.applicantPhone, "+21612345678");
  assert.deepEqual(body.photos.map((p) => [p.kind, p.image]), [
    ["id", true],
    ["business", false],
    ["logo", true],
  ]);
  assert.ok(fake.signed.every((s) => s.seconds === PHOTO_LINK_SECONDS && s.bucket === "visitor-documents"));
  assert.equal(PHOTO_LINK_SECONDS, 300);
  assert.equal(fake.decided.length, 0);
  assert.equal(fake.hash, await hashToken(TOKEN));
  // The answer never carries the file paths or the token.
  assert.doesNotMatch(JSON.stringify(answer.body.application), /anon\/a1|id-1|TTTT/);
});

Deno.test("an account application's files come from their own buckets", async () => {
  const fake = new Fake();
  fake.app = details({ origin: "account", logoPath: "user_1/logo.png" });

  await handleReview(fake, { token: TOKEN, action: "view" });

  assert.deepEqual(fake.signed.map((s) => s.bucket), [
    "application-documents",
    "application-documents",
    "store-logos",
  ]);
});

Deno.test("a file that is missing is left out, not an error", async () => {
  const fake = new Fake();
  fake.missingFiles.add("anon/a1/logo-1.png");

  const answer = await handleReview(fake, { token: TOKEN, action: "view" });

  assert.equal(answer.status, 200);
  assert.equal((answer.body.photos as unknown[]).length, 2);
});

Deno.test("unknown, expired and used tokens all get the same 404 and no data", async () => {
  const cases: (TokenRow | null)[] = [
    null,
    { applicationId: APP, usedAt: null, expiresAt: "2026-10-05T09:59:59Z" },
    { applicationId: APP, usedAt: "2026-10-05T09:00:00Z", expiresAt: "2026-10-12T10:00:00Z" },
  ];
  const answers = [];
  for (const row of cases) {
    const fake = new Fake();
    fake.token = row;
    for (const action of ["view", "approve", "reject"]) {
      answers.push(await handleReview(fake, { token: TOKEN, action, reason: "no" }));
      assert.equal(fake.decided.length, 0);
    }
  }
  for (const answer of answers) {
    assert.deepEqual(answer, { status: 404, body: { error: "invalid_link" } });
  }
});

Deno.test("a token of the wrong shape is invalid_link without a lookup", async () => {
  const fake = new Fake();
  for (const token of [undefined, 5, "", "short", "x".repeat(101)]) {
    assert.deepEqual(await handleReview(fake, { token, action: "view" }), {
      status: 404,
      body: { error: "invalid_link" },
    });
  }
  assert.equal(fake.hash, "");
});

Deno.test("a bad action or body is a 400", async () => {
  const fake = new Fake();
  for (const body of [null, "x", {}, { token: TOKEN }, { token: TOKEN, action: "delete" }]) {
    assert.deepEqual(await handleReview(fake, body), { status: 400, body: { error: "bad_request" } });
  }
});

Deno.test("approve decides through the database function and returns the status", async () => {
  const fake = new Fake();

  const answer = await handleReview(fake, { token: TOKEN, action: "approve" });

  assert.deepEqual(answer, { status: 200, body: { status: "approved" } });
  assert.deepEqual(fake.decided, [{ hash: await hashToken(TOKEN), action: "approve", reason: null }]);
});

Deno.test("reject needs a trimmed reason of 1 to 500 characters, checked before the database", async () => {
  const fake = new Fake();
  fake.decision = "rejected";

  for (const reason of [undefined, "", "   ", 5, "x".repeat(501)]) {
    assert.deepEqual(await handleReview(fake, { token: TOKEN, action: "reject", reason }), {
      status: 422,
      body: { error: "reason_required" },
    });
  }
  assert.equal(fake.decided.length, 0);

  const ok = await handleReview(fake, { token: TOKEN, action: "reject", reason: "  Blurry ID  " });
  assert.deepEqual(ok, { status: 200, body: { status: "rejected" } });
  assert.equal(fake.decided[0].reason, "Blurry ID");

  fake.decided.length = 0;
  await handleReview(fake, { token: TOKEN, action: "reject", reason: "x".repeat(500) });
  assert.equal(fake.decided.length, 1);
});

Deno.test("an application someone else decided is a 409 already_decided", async () => {
  const fake = new Fake();
  fake.decision = "not_reviewing";

  assert.deepEqual(await handleReview(fake, { token: TOKEN, action: "approve" }), {
    status: 409,
    body: { error: "already_decided" },
  });
});

Deno.test("refusals from the database map to plain codes", async () => {
  const cases: [string, number, string][] = [
    ["already_seller", 409, "already_seller"],
    ["username_taken", 409, "username_taken"],
    ["reason_required", 422, "reason_required"],
    ["invalid_link", 404, "invalid_link"],
    ["not_found", 404, "invalid_link"],
    ["connection reset by v@example.com", 500, "failed"],
  ];
  for (const [message, status, error] of cases) {
    const fake = new Fake();
    fake.decision = new Error(message);
    const answer = await handleReview(fake, { token: TOKEN, action: "approve" });
    assert.deepEqual(answer, { status, body: { error } }, message);
  }
});
