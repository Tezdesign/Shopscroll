// Run with `deno test supabase/functions/_shared/admin_email_test.ts`.
// Needs no network: the database and Mailjet are fakes kept in memory. It uses
// only `Deno.test` and `node:assert`, so Node 22 can run it too
// (`node --experimental-strip-types`, with a `Deno.test` shim).

import assert from "node:assert/strict";
import {
  type ApplicationEmailData,
  buildMailjetMessage,
  buildReviewLink,
  escapeHtml,
  hashToken,
  type MailjetMessage,
  newToken,
  notifyAdmin,
  type NotifyDeps,
  oneLine,
  secretsMatch,
  type SendResult,
  sendWithMailjet,
} from "./admin_email.ts";

const APP = "00000000-0000-0000-0000-0000000000a1";
const CONFIG = {
  reviewPageUrl: "https://review.example.pages.dev/",
  sender: "no-reply@shop.example",
  admin: "admin@shop.example",
};

function application(overrides: Partial<ApplicationEmailData> = {}): ApplicationEmailData {
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
    createdAt: "2026-10-05T10:00:00Z",
    applicantName: "Visitor One",
    applicantEmail: "v@example.com",
    applicantPhone: "+21612345678",
    ...overrides,
  };
}

/// A fake world: what the database holds, what Mailjet answers, and a log of
/// everything that was asked.
class Fake implements NotifyDeps {
  data: ApplicationEmailData | null = application();
  leaseFree = true;
  sendResult: SendResult = { ok: true };
  failOn: string | null = null;
  tokens: { applicationId: string; hash: string; expiresAt: Date }[] = [];
  sent: MailjetMessage[] = [];
  notified: string[] = [];
  errors: string[] = [];
  clock = new Date("2026-10-05T10:00:00Z");

  load(_id: string) {
    if (this.failOn === "load") return Promise.reject(new Error("db down"));
    return Promise.resolve(this.data);
  }
  claim(_id: string) {
    const free = this.leaseFree;
    this.leaseFree = false;
    return Promise.resolve(free);
  }
  saveToken(applicationId: string, hash: string, expiresAt: Date) {
    if (this.failOn === "saveToken") return Promise.reject(new Error("db down"));
    this.tokens.push({ applicationId, hash, expiresAt });
    return Promise.resolve();
  }
  markNotified(id: string) {
    this.notified.push(id);
    return Promise.resolve();
  }
  markError(_id: string, code: string) {
    this.errors.push(code);
    return Promise.resolve();
  }
  send(message: MailjetMessage) {
    this.sent.push(message);
    return Promise.resolve(this.sendResult);
  }
  now() {
    return this.clock;
  }
}

Deno.test("escapeHtml stops markup and quotes", () => {
  assert.equal(
    escapeHtml(`<a href="x" onclick='y'>&</a>`),
    "&lt;a href=&quot;x&quot; onclick=&#39;y&#39;&gt;&amp;&lt;/a&gt;",
  );
});

Deno.test("oneLine removes line breaks and control characters, and caps the length", () => {
  assert.equal(oneLine("A\r\nBcc: evil@x.com\u0000"), "A Bcc: evil@x.com");
  assert.equal(oneLine("x".repeat(300)).length, 100);
});

Deno.test("tokens are 32 random bytes, URL safe, and differ each time", () => {
  const a = newToken();
  const b = newToken();
  assert.match(a, /^[A-Za-z0-9_-]{43}$/);
  assert.notEqual(a, b);
});

Deno.test("hashToken is the SHA-256 hex of the token", async () => {
  assert.equal(
    await hashToken("abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  );
});

Deno.test("secretsMatch is true only for the same secret", async () => {
  assert.equal(await secretsMatch("s3cret", "s3cret"), true);
  assert.equal(await secretsMatch("s3cret", "s3cret!"), false);
  assert.equal(await secretsMatch("", "s3cret"), false);
});

Deno.test("the review link puts the token in the fragment and drops an old one", () => {
  assert.equal(
    buildReviewLink("https://r.example/page/", "TOKEN"),
    "https://r.example/page/#t=TOKEN",
  );
  assert.equal(
    buildReviewLink("https://r.example/page/#old", "TOKEN"),
    "https://r.example/page/#t=TOKEN",
  );
});

Deno.test("the message lists the details and the link, has tracking off, and no photos", () => {
  const message = buildMailjetMessage(
    application({ bio: "Hello", websiteUrl: "https://w.example" }),
    "https://r.example/#t=TOKEN",
    CONFIG.sender,
    CONFIG.admin,
  );
  for (const part of [message.TextPart, message.HTMLPart]) {
    assert.match(part, /Warda Shop/);
    assert.match(part, /warda/);
    assert.match(part, /Visitor One/);
    assert.match(part, /\+21612345678/);
    assert.match(part, /Hello/);
    assert.match(part, /https:\/\/r\.example\/#t=TOKEN/);
    assert.doesNotMatch(part, /visitor-documents|application-documents|id-|\.jpg|\.png/);
  }
  assert.equal(message.TrackClicks, "disabled");
  assert.equal(message.TrackOpens, "disabled");
  assert.equal(message.CustomID, APP);
  assert.deepEqual(message.To, [{ Email: CONFIG.admin }]);
  assert.equal(message.From.Email, CONFIG.sender);
  assert.equal(message.Subject, "New seller application: Warda Shop");
});

Deno.test("empty optional fields are left out", () => {
  const message = buildMailjetMessage(application(), "L", CONFIG.sender, CONFIG.admin);
  assert.doesNotMatch(message.TextPart, /About:|Website:|Store phone:|Store email:/);
});

Deno.test("typed text cannot add markup, links or subject lines", () => {
  const message = buildMailjetMessage(
    application({
      storeName: `Shop\r\nBcc: evil@x.com <script>alert(1)</script>`,
      bio: `<a href="https://evil.example">click</a>`,
      applicantName: `"><img src=x onerror=alert(1)>`,
    }),
    "https://r.example/#t=TOKEN",
    CONFIG.sender,
    CONFIG.admin,
  );
  assert.doesNotMatch(message.Subject, /[\r\n]/);
  assert.doesNotMatch(message.HTMLPart, /<script|<img|<a href="https:\/\/evil/);
  assert.match(message.HTMLPart, /&lt;script&gt;/);
  assert.equal((message.HTMLPart.match(/<a href=/g) ?? []).length, 1);
});

Deno.test("an account application is labelled as such", () => {
  const message = buildMailjetMessage(
    application({ origin: "account" }),
    "L",
    CONFIG.sender,
    CONFIG.admin,
  );
  assert.match(message.TextPart, /Signed in account/);
});

Deno.test("Mailjet success is HTTP 200 and a success status, sent with Basic auth", async () => {
  let call: { url: string; init: RequestInit } | null = null;
  const fetchFn = ((url: string, init: RequestInit) => {
    call = { url, init };
    return Promise.resolve(
      new Response(JSON.stringify({ Messages: [{ Status: "success" }] }), { status: 200 }),
    );
  }) as unknown as typeof fetch;
  const message = buildMailjetMessage(application(), "L", CONFIG.sender, CONFIG.admin);

  assert.deepEqual(await sendWithMailjet(fetchFn, "key", "secret", message), { ok: true });
  assert.equal(call!.url, "https://api.mailjet.com/v3.1/send");
  assert.equal(
    (call!.init.headers as Record<string, string>).Authorization,
    `Basic ${btoa("key:secret")}`,
  );
  const body = JSON.parse(call!.init.body as string);
  assert.equal(body.Messages[0].TrackClicks, "disabled");
});

Deno.test("Mailjet failures become short codes with nothing personal in them", async () => {
  const message = buildMailjetMessage(application(), "L", CONFIG.sender, CONFIG.admin);
  const answer = (status: number, body: string) =>
    (() => Promise.resolve(new Response(body, { status }))) as unknown as typeof fetch;

  assert.deepEqual(
    await sendWithMailjet(answer(401, "v@example.com"), "k", "s", message),
    { ok: false, code: "mailjet_http_401" },
  );
  assert.deepEqual(
    await sendWithMailjet(
      answer(200, JSON.stringify({ Messages: [{ Status: "error" }] })),
      "k",
      "s",
      message,
    ),
    { ok: false, code: "mailjet_status_error" },
  );
  assert.deepEqual(
    await sendWithMailjet(answer(200, "not json"), "k", "s", message),
    { ok: false, code: "mailjet_bad_answer" },
  );
  const down = (() => Promise.reject(new Error("v@example.com unreachable"))) as unknown as typeof fetch;
  assert.deepEqual(await sendWithMailjet(down, "k", "s", message), {
    ok: false,
    code: "mailjet_network",
  });
});

Deno.test("a new application sends one email with a link whose token is stored hashed for 7 days", async () => {
  const fake = new Fake();

  const result = await notifyAdmin(fake, CONFIG, APP);

  assert.deepEqual(result, { sent: true });
  assert.equal(fake.sent.length, 1);
  assert.deepEqual(fake.notified, [APP]);
  assert.equal(fake.tokens.length, 1);
  const link = fake.sent[0].TextPart.match(/#t=([A-Za-z0-9_-]+)/)!;
  assert.equal(fake.tokens[0].hash, await hashToken(link[1]));
  assert.ok(!fake.tokens[0].hash.includes(link[1]));
  assert.equal(
    fake.tokens[0].expiresAt.getTime() - fake.clock.getTime(),
    7 * 24 * 60 * 60 * 1000,
  );
});

Deno.test("an already notified application sends nothing", async () => {
  const fake = new Fake();
  fake.data = application({ adminNotifiedAt: "2026-10-05T10:01:00Z" });

  assert.deepEqual(await notifyAdmin(fake, CONFIG, APP), {
    sent: false,
    reason: "already_sent",
  });
  assert.equal(fake.sent.length, 0);
  assert.equal(fake.tokens.length, 0);
});

Deno.test("two calls close together send one email (the lease)", async () => {
  const fake = new Fake();

  const [a, b] = await Promise.all([
    notifyAdmin(fake, CONFIG, APP),
    notifyAdmin(fake, CONFIG, APP),
  ]);

  assert.equal(fake.sent.length, 1);
  assert.deepEqual([a.sent, b.sent].sort(), [false, true]);
});

Deno.test("an application decided before the email went out is marked notified and sends nothing", async () => {
  const fake = new Fake();
  fake.data = application({ status: "approved" });

  assert.deepEqual(await notifyAdmin(fake, CONFIG, APP), {
    sent: false,
    reason: "not_reviewing",
  });
  assert.equal(fake.sent.length, 0);
  assert.deepEqual(fake.notified, [APP]);
});

Deno.test("an unknown application sends nothing", async () => {
  const fake = new Fake();
  fake.data = null;

  assert.deepEqual(await notifyAdmin(fake, CONFIG, APP), {
    sent: false,
    reason: "not_found",
  });
});

Deno.test("a Mailjet failure leaves the application unsent and saves a short code", async () => {
  const fake = new Fake();
  fake.sendResult = { ok: false, code: "mailjet_http_401" };

  assert.deepEqual(await notifyAdmin(fake, CONFIG, APP), {
    sent: false,
    reason: "mailjet_http_401",
  });
  assert.deepEqual(fake.notified, []);
  assert.deepEqual(fake.errors, ["mailjet_http_401"]);
});

Deno.test("a database failure never throws and saves internal_error", async () => {
  for (const failOn of ["load", "saveToken"]) {
    const fake = new Fake();
    fake.failOn = failOn;

    const result = await notifyAdmin(fake, CONFIG, APP);

    assert.deepEqual(result, { sent: false, reason: "internal_error" });
    assert.deepEqual(fake.errors, ["internal_error"]);
    assert.equal(fake.sent.length, 0);
  }
});
