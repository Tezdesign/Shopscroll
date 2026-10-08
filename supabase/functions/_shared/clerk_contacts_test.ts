// Run with `deno test supabase/functions/_shared/clerk_contacts_test.ts`.
// Needs no network: Clerk is a fake `fetch`. It uses only `Deno.test` and
// `node:assert`, so Node 22 can run it too (`node --experimental-strip-types`,
// with a `Deno.test` shim).

import assert from "node:assert/strict";
import { verifiedContacts } from "./clerk_contacts.ts";

function fakeFetch(status: number, body: unknown, seen: { url?: string; auth?: string } = {}) {
  return ((url: string, init?: RequestInit) => {
    seen.url = url;
    seen.auth = (init?.headers as Record<string, string>)?.Authorization;
    return Promise.resolve(new Response(JSON.stringify(body), { status }));
  }) as unknown as typeof fetch;
}

Deno.test("AC-12 returns only the emails and phones Clerk verified", async () => {
  const seen: { url?: string; auth?: string } = {};
  const contacts = await verifiedContacts(
    fakeFetch(200, {
      email_addresses: [
        { email_address: "ok@example.com", verification: { status: "verified" } },
        { email_address: "pending@example.com", verification: { status: "unverified" } },
        { email_address: "none@example.com", verification: null },
        { email_address: "expired@example.com", verification: { status: "expired" } },
      ],
      phone_numbers: [
        { phone_number: "+21612345678", verification: { status: "verified" } },
        { phone_number: "+21699999999", verification: { status: "unverified" } },
        { phone_number: "+21600000000" },
      ],
    }, seen),
    "sk_test",
    "user_1",
  );
  assert.deepEqual(contacts, { emails: ["ok@example.com"], phones: ["+21612345678"] });
  assert.equal(seen.url, "https://api.clerk.com/v1/users/user_1");
  assert.equal(seen.auth, "Bearer sk_test");
});

Deno.test("AC-12 an account with no phone numbers gives an empty phone list", async () => {
  const contacts = await verifiedContacts(
    fakeFetch(200, { email_addresses: [], phone_numbers: [] }),
    "sk",
    "u",
  );
  assert.deepEqual(contacts, { emails: [], phones: [] });
});

Deno.test("AC-12 an HTTP failure or an unexpected answer throws", async () => {
  await assert.rejects(verifiedContacts(fakeFetch(503, {}), "sk", "u"), /clerk_http_503/);
  await assert.rejects(verifiedContacts(fakeFetch(200, { nope: 1 }), "sk", "u"), /clerk_bad_answer/);
  await assert.rejects(
    verifiedContacts(fakeFetch(200, { email_addresses: [] }), "sk", "u"),
    /clerk_bad_answer/,
  );
  await assert.rejects(
    verifiedContacts((() => Promise.reject(new Error("offline"))) as unknown as typeof fetch, "sk", "u"),
    /offline/,
  );
});

Deno.test("AC-12 the user id is encoded into the path", async () => {
  const seen: { url?: string } = {};
  await verifiedContacts(fakeFetch(200, { email_addresses: [], phone_numbers: [] }, seen), "sk", "a/b");
  assert.equal(seen.url, "https://api.clerk.com/v1/users/a%2Fb");
});
