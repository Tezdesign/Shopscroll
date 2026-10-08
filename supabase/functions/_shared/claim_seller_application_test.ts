// Run with `deno test supabase/functions/_shared/claim_seller_application_test.ts`.
// Needs no network: the database and Storage are fakes kept in memory. It uses
// only `Deno.test` and `node:assert`, so Node 22 can run it too
// (`node --experimental-strip-types`, with a `Deno.test` shim).

import assert from "node:assert/strict";
import {
  type ClaimClient,
  claimSellerApplication,
  LOGO_BUCKET,
  VISITOR_BUCKET,
} from "./claim_seller_application.ts";

type Err = { message: string; statusCode?: string } | null;

/// A fake client. `claimable` is what `find_claimable_application` returns,
/// `claimError` what `claim_seller_application` answers, and `copyError` what the
/// Storage copy answers. Everything it was asked is recorded in `calls`.
class FakeClient implements ClaimClient {
  calls: { fn: string; args: Record<string, unknown> }[] = [];
  copies: { from: string; to: string; bucket: string; destination: string }[] =
    [];
  claimable: { id: string; logo_path: string | null }[] = [];
  findError: Err = null;
  claimError: Err = null;
  copyError: Err = null;
  /// What `has_unattached_visitor_applications` says, how many rows
  /// `attach_applications_by_contact` attaches, the row that attaching makes
  /// claimable, and the role the profile has.
  waiting = false;
  role: string | null = "buyer";
  attachCount = 0;
  attachError: Err = null;
  claimableAfterAttach: { id: string; logo_path: string | null }[] = [];

  rpc(fn: string, args: Record<string, unknown>) {
    this.calls.push({ fn, args });
    if (fn === "has_unattached_visitor_applications") {
      return Promise.resolve({ data: this.waiting, error: null });
    }
    if (fn === "attach_applications_by_contact") {
      if (this.attachCount > 0) this.claimable = this.claimableAfterAttach;
      return Promise.resolve({ data: this.attachCount, error: this.attachError });
    }
    if (fn === "find_claimable_application") {
      return Promise.resolve({ data: this.claimable, error: this.findError });
    }
    return Promise.resolve({ data: null, error: this.claimError });
  }

  from = (_table: string) => ({
    select: (_columns: string) => ({
      eq: (_column: string, _value: string) => ({
        maybeSingle: () =>
          Promise.resolve({
            data: this.role === null ? null : { role: this.role },
            error: null,
          }),
      }),
    }),
  });

  storage = {
    from: (bucket: string) => ({
      copy: (
        from: string,
        to: string,
        options: { destinationBucket: string },
      ) => {
        this.copies.push({
          from,
          to,
          bucket,
          destination: options.destinationBucket,
        });
        return Promise.resolve({ data: null, error: this.copyError });
      },
    }),
  };

  called(fn: string) {
    return this.calls.filter((call) => call.fn === fn);
  }

  claimCalls() {
    return this.calls.filter((call) => call.fn === "claim_seller_application");
  }
}

const APP = "00000000-0000-0000-0000-0000000000e1";
const LOGO = `anon_1/${APP}/logo-abc.PNG`;

Deno.test("nothing to claim returns claimed false and touches nothing", async () => {
  const client = new FakeClient();
  assert.deepEqual(await claimSellerApplication(client, "user_1"), {
    claimed: false,
  });
  assert.equal(client.copies.length, 0);
  assert.equal(client.claimCalls().length, 0);
});

Deno.test("copies the logo to its fixed destination, then claims with that path", async () => {
  const client = new FakeClient();
  client.claimable = [{ id: APP, logo_path: LOGO }];
  assert.deepEqual(await claimSellerApplication(client, "user_1"), {
    claimed: true,
  });
  assert.deepEqual(client.copies, [{
    from: LOGO,
    to: `user_1/${APP}.png`,
    bucket: VISITOR_BUCKET,
    destination: LOGO_BUCKET,
  }]);
  assert.deepEqual(client.claimCalls()[0].args, {
    p_id: APP,
    p_clerk_id: "user_1",
    p_logo_path: `user_1/${APP}.png`,
  });
});

Deno.test("no logo means no copy and a null logo path", async () => {
  const client = new FakeClient();
  client.claimable = [{ id: APP, logo_path: null }];
  assert.deepEqual(await claimSellerApplication(client, "user_1"), {
    claimed: true,
  });
  assert.equal(client.copies.length, 0);
  assert.equal(client.claimCalls()[0].args.p_logo_path, null);
});

Deno.test("an existing destination counts as done", async () => {
  for (
    const error of [
      { message: "The resource already exists", statusCode: "409" },
      { message: "Duplicate", statusCode: "409" },
      { message: "The resource already exists" },
    ]
  ) {
    const client = new FakeClient();
    client.claimable = [{ id: APP, logo_path: LOGO }];
    client.copyError = error;
    assert.deepEqual(await claimSellerApplication(client, "user_1"), {
      claimed: true,
    });
    assert.equal(client.claimCalls().length, 1);
  }
});

Deno.test("any other copy error throws and does not claim", async () => {
  const client = new FakeClient();
  client.claimable = [{ id: APP, logo_path: LOGO }];
  client.copyError = { message: "Object not found", statusCode: "404" };
  await assert.rejects(claimSellerApplication(client, "user_1"), /not found/);
  assert.equal(client.claimCalls().length, 0);
});

Deno.test("a database refusal is claimed false with its reason", async () => {
  for (
    const reason of [
      "not_claimable",
      "not_found",
      "already_seller",
      "username_taken",
      "no_profile",
    ]
  ) {
    const client = new FakeClient();
    client.claimable = [{ id: APP, logo_path: null }];
    client.claimError = { message: reason };
    assert.deepEqual(await claimSellerApplication(client, "user_1"), {
      claimed: false,
      reason,
    });
  }
});

Deno.test("an unknown database error throws", async () => {
  const client = new FakeClient();
  client.claimable = [{ id: APP, logo_path: null }];
  client.claimError = { message: "connection reset" };
  await assert.rejects(claimSellerApplication(client, "user_1"), /connection/);
});

Deno.test("a failed lookup throws", async () => {
  const client = new FakeClient();
  client.findError = { message: "boom" };
  await assert.rejects(claimSellerApplication(client, "user_1"), /boom/);
});

Deno.test("an unsafe user id is refused before anything runs", async () => {
  for (const id of ["", ".", "..", "a/b"]) {
    const client = new FakeClient();
    await assert.rejects(claimSellerApplication(client, id), /invalid user id/);
    assert.equal(client.calls.length, 0);
  }
});

// ---------------------------------------------------------------- attach by contact

const contacts = (emails: string[], phones: string[] = []) => () =>
  Promise.resolve({ emails, phones });

Deno.test("AC-12 attaches by the verified contacts, then claims in the same call", async () => {
  const client = new FakeClient();
  client.waiting = true;
  client.attachCount = 1;
  client.claimableAfterAttach = [{ id: APP, logo_path: null }];
  const result = await claimSellerApplication(
    client,
    "user_1",
    contacts(["a@example.com"], ["+21612345678"]),
  );
  assert.deepEqual(result, { claimed: true });
  assert.deepEqual(client.called("attach_applications_by_contact")[0].args, {
    p_clerk_id: "user_1",
    p_emails: ["a@example.com"],
    p_phones: ["+21612345678"],
  });
  const order = client.calls.map((c) => c.fn);
  assert.ok(
    order.indexOf("attach_applications_by_contact") < order.indexOf("claim_seller_application"),
    "attach runs before the claim",
  );
});

Deno.test("AC-13 no Clerk request and no attach while no free visitor application waits", async () => {
  const client = new FakeClient();
  let clerkCalls = 0;
  const result = await claimSellerApplication(client, "user_1", () => {
    clerkCalls++;
    return Promise.resolve({ emails: ["a@example.com"], phones: [] });
  });
  assert.deepEqual(result, { claimed: false });
  assert.equal(clerkCalls, 0);
  assert.equal(client.called("attach_applications_by_contact").length, 0);
});

Deno.test("AC-13 a seller makes no Clerk request and no attach", async () => {
  const client = new FakeClient();
  client.role = "seller";
  client.waiting = true;
  let clerkCalls = 0;
  await claimSellerApplication(client, "user_1", () => {
    clerkCalls++;
    return Promise.resolve({ emails: ["a@example.com"], phones: [] });
  });
  assert.equal(clerkCalls, 0);
  assert.equal(client.called("has_unattached_visitor_applications").length, 0);
  assert.equal(client.called("attach_applications_by_contact").length, 0);
});

Deno.test("AC-13 the attach runs even when a row is already attached, then the claim runs", async () => {
  const client = new FakeClient();
  client.waiting = true;
  client.claimable = [{ id: APP, logo_path: null }];
  const result = await claimSellerApplication(client, "user_1", contacts(["a@example.com"]));
  assert.deepEqual(result, { claimed: true });
  assert.equal(client.called("attach_applications_by_contact").length, 1);
  assert.equal(client.claimCalls().length, 1);
});

Deno.test("AC-12 an account with no verified contact attaches nothing", async () => {
  const client = new FakeClient();
  client.waiting = true;
  const result = await claimSellerApplication(client, "user_1", contacts([], []));
  assert.deepEqual(result, { claimed: false });
  assert.equal(client.called("attach_applications_by_contact").length, 0);
});

Deno.test("AC-12 only a phone is enough to attach", async () => {
  const client = new FakeClient();
  client.waiting = true;
  await claimSellerApplication(client, "user_1", contacts([], ["+21612345678"]));
  assert.deepEqual(client.called("attach_applications_by_contact")[0].args, {
    p_clerk_id: "user_1",
    p_emails: [],
    p_phones: ["+21612345678"],
  });
});

Deno.test("AC-13 an attach with nothing claimable answers claimed false", async () => {
  const client = new FakeClient();
  client.waiting = true;
  client.attachCount = 1;
  const result = await claimSellerApplication(client, "user_1", contacts(["a@example.com"]));
  assert.deepEqual(result, { claimed: false });
  assert.equal(client.claimCalls().length, 0);
});

Deno.test("AC-13 a Clerk failure with nothing claimable throws and changes nothing", async () => {
  const client = new FakeClient();
  client.waiting = true;
  await assert.rejects(
    claimSellerApplication(client, "user_1", () => Promise.reject(new Error("clerk_http_503"))),
    /attach_failed/,
  );
  assert.equal(client.called("attach_applications_by_contact").length, 0);
  assert.equal(client.claimCalls().length, 0);
});

Deno.test("AC-13 a Clerk failure never blocks the claim of a row that is already attached", async () => {
  const client = new FakeClient();
  client.waiting = true;
  client.claimable = [{ id: APP, logo_path: null }];
  const result = await claimSellerApplication(
    client,
    "user_1",
    () => Promise.reject(new Error("clerk_http_503")),
  );
  assert.deepEqual(result, { claimed: true });
  assert.equal(client.claimCalls().length, 1);
});

Deno.test("AC-13 a failed attach call is survived the same way", async () => {
  const client = new FakeClient();
  client.waiting = true;
  client.attachError = { message: "boom with a@example.com inside" };
  await assert.rejects(
    claimSellerApplication(client, "user_1", contacts(["a@example.com"])),
    /attach_failed/,
  );
  client.claimable = [{ id: APP, logo_path: null }];
  assert.deepEqual(
    await claimSellerApplication(client, "user_1", contacts(["a@example.com"])),
    { claimed: true },
  );
});

Deno.test("AC-13 the log carries a short code, never the error message", async () => {
  const client = new FakeClient();
  client.waiting = true;
  client.attachError = { message: "duplicate key a@example.com" };
  const lines: unknown[][] = [];
  const original = console.log;
  console.log = (...args: unknown[]) => void lines.push(args);
  try {
    await assert.rejects(claimSellerApplication(client, "user_1", contacts(["a@example.com"])));
  } finally {
    console.log = original;
  }
  assert.ok(lines.length > 0);
  assert.ok(!JSON.stringify(lines).includes("a@example.com"));
  assert.ok(JSON.stringify(lines).includes("attach_failed"));
});

Deno.test("AC-13 without a contact reader nothing is attached and the plain claim still works", async () => {
  const client = new FakeClient();
  client.waiting = true;
  client.claimable = [{ id: APP, logo_path: null }];
  assert.deepEqual(await claimSellerApplication(client, "user_1"), { claimed: true });
  const other = new FakeClient();
  other.waiting = true;
  assert.deepEqual(await claimSellerApplication(other, "user_1"), { claimed: false });
  assert.equal(other.called("has_unattached_visitor_applications").length, 0);
});
