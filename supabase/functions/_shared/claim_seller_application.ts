// Decision record: docs/specs/_root/0014-shared-login-seller-area/index.md
// (AC-13, build plan task 3)
//
// The claim: an approved visitor application that was attached to this account
// (by `merge_anonymous_identity`, at sign in on the phone that sent it) turns the
// account into a seller. The Storage copy cannot run inside SQL, so this does
// the two steps in order: copy the logo from the private `visitor-documents`
// bucket to the public `store-logos` bucket, then call the database function
// `claim_seller_application`, which does the real work in one transaction.
//
// Kept apart from `claim-seller-application/index.ts` and free of any Deno or
// npm import, so a test can run it against fakes.

type ClientError = {
  message: string;
  status?: number | string;
  statusCode?: number | string;
};
type ClientResult<T> = { data: T | null; error: ClientError | null };

/// The slice of the Supabase client this needs, so a test can stand in for it.
/// `createClient(...)` with the service role key fits.
export interface ClaimClient {
  rpc(fn: string, args: Record<string, unknown>): Promise<ClientResult<unknown>>;
  storage: {
    from(bucket: string): {
      copy(
        from: string,
        to: string,
        options: { destinationBucket: string },
      ): Promise<ClientResult<unknown>>;
    };
  };
}

export const VISITOR_BUCKET = "visitor-documents";
export const LOGO_BUCKET = "store-logos";

/// What the database says when a claim cannot go ahead. Each leaves the
/// application and the profile as they were, and the caller simply is not a
/// seller yet. `not_claimable` is also what a second or simultaneous call sees.
const REFUSALS = [
  "not_claimable",
  "not_found",
  "already_seller",
  "username_taken",
  "no_profile",
];

/// Storage answers 409 when the destination file exists. A claim that was cut
/// off after the copy retries into this, and an existing logo means done.
function alreadyExists(error: ClientError): boolean {
  return String(error.statusCode ?? error.status) === "409" ||
    /already exists/i.test(error.message);
}

/// Claims the caller's approved visitor application, if there is one.
/// Returns `claimed: true` only when this call made them a seller. A refusal
/// from the database (see REFUSALS) is `claimed: false` with its `reason`, and
/// anything else (network, Storage) throws so the caller can report a failure
/// and the app can try again later.
export async function claimSellerApplication(
  client: ClaimClient,
  clerkId: string,
): Promise<{ claimed: boolean; reason?: string }> {
  // The id is a folder name in `store-logos`. An empty one, or one with a slash
  // or a dot segment, would reach another folder.
  if (
    clerkId.length === 0 || clerkId.includes("/") || clerkId === "." ||
    clerkId === ".."
  ) {
    throw new Error("invalid user id");
  }

  const found = await client.rpc("find_claimable_application", {
    p_clerk_id: clerkId,
  });
  if (found.error) throw new Error(found.error.message);
  const row = (found.data as { id: string; logo_path: string | null }[] | null)
    ?.[0];
  if (!row) return { claimed: false };

  let logoDestination: string | null = null;
  if (row.logo_path) {
    const extension = /\.([a-z0-9]+)$/i.exec(row.logo_path)?.[1]
      ?.toLowerCase() ?? "jpg";
    logoDestination = `${clerkId}/${row.id}.${extension}`;
    const { error } = await client.storage.from(VISITOR_BUCKET).copy(
      row.logo_path,
      logoDestination,
      { destinationBucket: LOGO_BUCKET },
    );
    if (error && !alreadyExists(error)) throw new Error(error.message);
  }

  const { error } = await client.rpc("claim_seller_application", {
    p_id: row.id,
    p_clerk_id: clerkId,
    p_logo_path: logoDestination,
  });
  if (!error) return { claimed: true };
  if (REFUSALS.includes(error.message)) {
    return { claimed: false, reason: error.message };
  }
  throw new Error(error.message);
}
