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

  rpc(fn: string, args: Record<string, unknown>) {
    this.calls.push({ fn, args });
    if (fn === "find_claimable_application") {
      return Promise.resolve({ data: this.claimable, error: this.findError });
    }
    return Promise.resolve({ data: null, error: this.claimError });
  }

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
