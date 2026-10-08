// Run with `deno test supabase/functions/_shared/applicant_email_test.ts`.
// Needs no network: the database and Mailjet are fakes kept in memory. It uses
// only `Deno.test` and `node:assert`, so Node 22 can run it too
// (`node --experimental-strip-types`, with a `Deno.test` shim).

import assert from "node:assert/strict";
import type { MailjetMessage, SendResult } from "./admin_email.ts";
import {
  type ApplicantEmailData,
  type ApplicantNotifyDeps,
  buildApplicantMessage,
  notifyApplicant,
  recipientFor,
} from "./applicant_email.ts";

const APP = "00000000-0000-0000-0000-0000000000a1";
const CONFIG = { sender: "no-reply@shop.example", admin: "admin@shop.example" };

function row(overrides: Partial<ApplicantEmailData> = {}): ApplicantEmailData {
  return {
    id: APP,
    origin: "visitor",
    status: "approved",
    applicantNotifiedAt: null,
    storeName: "Warda Shop",
    rejectionReason: null,
    applicantEmail: "v@example.com",
    contactEmail: null,
    ...overrides,
  };
}

class Fake implements ApplicantNotifyDeps {
  data: ApplicantEmailData | null = row();
  leaseFree = true;
  sendResult: SendResult = { ok: true };
  failOn: string | null = null;
  sent: MailjetMessage[] = [];
  notified: string[] = [];
  errors: string[] = [];

  load(_id: string) {
    if (this.failOn === "load") return Promise.reject(new Error("db down"));
    return Promise.resolve(this.data);
  }
  claim(_id: string) {
    const free = this.leaseFree;
    this.leaseFree = false;
    return Promise.resolve(free);
  }
  markNotified(id: string) {
    this.notified.push(id);
    return Promise.resolve();
  }
  markError(id: string, code: string) {
    this.errors.push(`${id}:${code}`);
    return Promise.resolve();
  }
  send(message: MailjetMessage) {
    this.sent.push(message);
    return Promise.resolve(this.sendResult);
  }
}

Deno.test("AC-2 recipient: visitor uses applicant_email only", () => {
  assert.equal(recipientFor(row({ contactEmail: "shop@example.com" })), "v@example.com");
  assert.equal(recipientFor(row({ applicantEmail: null, contactEmail: "shop@example.com" })), null);
});

Deno.test("AC-2 recipient: account prefers applicant_email, then the store email, never a profile", () => {
  const account = { origin: "account" as const, contactEmail: "shop@example.com" };
  assert.equal(recipientFor(row({ ...account, applicantEmail: "me@example.com" })), "me@example.com");
  assert.equal(recipientFor(row({ ...account, applicantEmail: "  " })), "shop@example.com");
  assert.equal(recipientFor(row({ ...account, applicantEmail: null })), "shop@example.com");
  assert.equal(recipientFor(row({ ...account, applicantEmail: null, contactEmail: null })), null);
});

Deno.test("AC-3 approval for a visitor shows both paths and the address", () => {
  const m = buildApplicantMessage(row(), "v@example.com", CONFIG.sender, CONFIG.admin);
  assert.match(m.Subject, /Warda Shop/);
  assert.doesNotMatch(m.Subject, /[\r\n]/);
  for (const part of [m.TextPart, m.HTMLPart]) {
    assert.match(part, /Congratulations/);
    assert.match(part, /Warda Shop/);
    assert.match(part, /New here\? Create an account with exactly this email address/);
    assert.match(part, /v@example\.com/);
    assert.match(part, /Already have an account with this email\?/);
    assert.match(part, /Buyer or Store owner switch at the top of the Profile tab/);
    assert.doesNotMatch(part, /https?:\/\//);
  }
});

Deno.test("AC-3 approval for an account shows the switch path only", () => {
  const m = buildApplicantMessage(
    row({ origin: "account" }),
    "me@example.com",
    CONFIG.sender,
    CONFIG.admin,
  );
  for (const part of [m.TextPart, m.HTMLPart]) {
    assert.match(part, /Your account is now a store owner account/);
    assert.match(part, /Buyer or Store owner switch/);
    assert.doesNotMatch(part, /Create an account/);
  }
});

Deno.test("AC-4 rejection names the store, shows the reason and how to apply again", () => {
  const m = buildApplicantMessage(
    row({ status: "rejected", rejectionReason: "ID photo is blurry" }),
    "v@example.com",
    CONFIG.sender,
    CONFIG.admin,
  );
  assert.match(m.Subject, /not approved/);
  for (const part of [m.TextPart, m.HTMLPart]) {
    assert.match(part, /Warda Shop/);
    assert.match(part, /ID photo is blurry/);
    assert.match(part, /Apply now/);
    assert.match(part, /Settings and then Seller application/);
  }
});

Deno.test("AC-4 markup in the store name or reason is escaped, the subject is one line", () => {
  const m = buildApplicantMessage(
    row({
      status: "rejected",
      storeName: "<b>Evil</b>\r\nBcc: x@y.z",
      rejectionReason: "<script>alert(1)</script>\nsecond line",
    }),
    "v@example.com",
    CONFIG.sender,
    CONFIG.admin,
  );
  assert.doesNotMatch(m.Subject, /[\r\n]/);
  assert.doesNotMatch(m.HTMLPart, /<script>|<b>Evil/);
  assert.match(m.HTMLPart, /&lt;script&gt;/);
  assert.match(m.HTMLPart, /second line/);
  assert.match(m.HTMLPart, /<br>/);
});

Deno.test("AC-5 sender, reply to, tracking off, custom id, both parts", () => {
  const m = buildApplicantMessage(row(), "v@example.com", CONFIG.sender, CONFIG.admin);
  assert.equal(m.From.Email, CONFIG.sender);
  assert.deepEqual(m.To, [{ Email: "v@example.com" }]);
  assert.deepEqual(m.ReplyTo, { Email: CONFIG.admin });
  assert.equal(m.TrackClicks, "disabled");
  assert.equal(m.TrackOpens, "disabled");
  assert.equal(m.CustomID, APP);
  assert.ok(m.TextPart.length > 0 && m.HTMLPart.length > 0);
});

Deno.test("AC-1 a decided application sends one email and is marked notified", async () => {
  const fake = new Fake();
  const result = await notifyApplicant(fake, CONFIG, APP);
  assert.deepEqual(result, { sent: true });
  assert.equal(fake.sent.length, 1);
  assert.deepEqual(fake.notified, [APP]);
  assert.deepEqual(fake.errors, []);
});

Deno.test("AC-6 an already notified or undecided application sends nothing", async () => {
  const done = new Fake();
  done.data = row({ applicantNotifiedAt: "2026-10-05T10:00:00Z" });
  assert.deepEqual(await notifyApplicant(done, CONFIG, APP), { sent: false, reason: "already_sent" });
  const open = new Fake();
  open.data = row({ status: "reviewing" });
  assert.deepEqual(await notifyApplicant(open, CONFIG, APP), { sent: false, reason: "not_decided" });
  const gone = new Fake();
  gone.data = null;
  assert.deepEqual(await notifyApplicant(gone, CONFIG, APP), { sent: false, reason: "not_found" });
  for (const f of [done, open, gone]) {
    assert.equal(f.sent.length, 0);
    assert.deepEqual(f.notified, []);
  }
});

Deno.test("AC-6 two calls close together send one email (the lease)", async () => {
  const fake = new Fake();
  const [a, b] = await Promise.all([
    notifyApplicant(fake, CONFIG, APP),
    notifyApplicant(fake, CONFIG, APP),
  ]);
  assert.equal(fake.sent.length, 1);
  assert.deepEqual([a.sent, b.sent].sort(), [false, true]);
});

Deno.test("AC-2 no address sends nothing and saves no_recipient", async () => {
  const fake = new Fake();
  fake.data = row({ origin: "account", applicantEmail: null, contactEmail: null });
  assert.deepEqual(await notifyApplicant(fake, CONFIG, APP), { sent: false, reason: "no_recipient" });
  assert.equal(fake.sent.length, 0);
  assert.deepEqual(fake.errors, [`${APP}:no_recipient`]);
});

Deno.test("AC-6 a Mailjet failure keeps the row unsent and saves a short code", async () => {
  const fake = new Fake();
  fake.sendResult = { ok: false, code: "mailjet_http_401" };
  assert.deepEqual(await notifyApplicant(fake, CONFIG, APP), { sent: false, reason: "mailjet_http_401" });
  assert.deepEqual(fake.notified, []);
  assert.deepEqual(fake.errors, [`${APP}:mailjet_http_401`]);
});

Deno.test("AC-1 a database failure never throws and saves internal_error", async () => {
  const fake = new Fake();
  fake.failOn = "load";
  assert.deepEqual(await notifyApplicant(fake, CONFIG, APP), { sent: false, reason: "internal_error" });
  assert.deepEqual(fake.errors, [`${APP}:internal_error`]);
});

Deno.test("AC-13 the saved codes hold no personal data", async () => {
  const fake = new Fake();
  fake.data = row({ storeName: "Secret Store", applicantEmail: "private@example.com" });
  fake.sendResult = { ok: false, code: "mailjet_network" };
  await notifyApplicant(fake, CONFIG, APP);
  for (const e of fake.errors) assert.doesNotMatch(e, /Secret|private@/);
});
