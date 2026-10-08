// Decision record: docs/specs/_root/0014-shared-login-seller-area/index.md
// (AC-12, AC-13, build plan tasks 3 and 12)
//
// First the attach: a free visitor application whose typed email or phone Clerk
// has verified for this account is attached to it (`attach_applications_by_contact`).
// Then the claim: an approved visitor application attached to this account turns
// it into a seller. The Storage copy cannot run inside SQL, so the claim does the
// two steps in order: copy the logo from the private `visitor-documents` bucket
// to the public `store-logos` bucket, then call the database function
// `claim_seller_application`, which does the real work in one transaction.
//
// Kept apart from `claim-seller-application/index.ts` and free of any Deno or
// npm import, so a test can run it against fakes.

import type { VerifiedContacts } from "./clerk_contacts.ts";

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
  from(table: string): {
    select(columns: string): {
      eq(column: string, value: string): {
        maybeSingle(): Promise<ClientResult<{ role: string | null }>>;
      };
    };
  };
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

/// Reads the oldest approved visitor application attached to the account.
async function findClaimable(
  client: ClaimClient,
  clerkId: string,
): Promise<{ id: string; logo_path: string | null } | undefined> {
  const found = await client.rpc("find_claimable_application", {
    p_clerk_id: clerkId,
  });
  if (found.error) throw new Error(found.error.message);
  return (found.data as { id: string; logo_path: string | null }[] | null)?.[0];
}

/// Attaches the free visitor applications whose typed email or phone is one of
/// the contacts Clerk has verified for the account (AC-12). Does nothing for a
/// seller, and asks the database first, so no Clerk request is made while no free
/// visitor application waits. Throws on a database or Clerk failure; nothing has
/// changed then.
async function attachByVerifiedContact(
  client: ClaimClient,
  clerkId: string,
  verifiedContacts: () => Promise<VerifiedContacts>,
): Promise<void> {
  const profile = await client.from("user_profiles").select("role").eq("id", clerkId)
    .maybeSingle();
  if (profile.error) throw new Error(profile.error.message);
  if (profile.data?.role === "seller") return;

  const waiting = await client.rpc("has_unattached_visitor_applications", {});
  if (waiting.error) throw new Error(waiting.error.message);
  if (waiting.data !== true) return;

  const { emails, phones } = await verifiedContacts();
  if (emails.length === 0 && phones.length === 0) return;
  const attached = await client.rpc("attach_applications_by_contact", {
    p_clerk_id: clerkId,
    p_emails: emails,
    p_phones: phones,
  });
  if (attached.error) throw new Error(attached.error.message);
}

/// A short code for the log, never the message itself: a database or Clerk
/// message could carry a contact detail.
function logCode(error: unknown): string {
  const message = error instanceof Error ? error.message : "";
  return /^[a-z0-9_]{1,40}$/.test(message) ? message : "attach_failed";
}

/// Attaches, then claims the caller's approved visitor application, if there is
/// one. `verifiedContacts` reads what Clerk has verified for the account; without
/// it nothing is attached. A failure of the attach (Clerk, database) never blocks
/// the claim of a row that is already attached: it is logged as a short code and
/// the claim runs. It becomes an error only when nothing was claimed, so the app
/// knows to ask again later. Returns `claimed: true` only when this call made the
/// account a seller. A refusal from the database (see REFUSALS) is
/// `claimed: false` with its `reason`, and anything else (network, Storage)
/// throws so the caller can report a failure.
export async function claimSellerApplication(
  client: ClaimClient,
  clerkId: string,
  verifiedContacts?: () => Promise<VerifiedContacts>,
): Promise<{ claimed: boolean; reason?: string }> {
  // The id is a folder name in `store-logos`. An empty one, or one with a slash
  // or a dot segment, would reach another folder.
  if (
    clerkId.length === 0 || clerkId.includes("/") || clerkId === "." ||
    clerkId === ".."
  ) {
    throw new Error("invalid user id");
  }

  let attachFailed = false;
  if (verifiedContacts) {
    try {
      await attachByVerifiedContact(client, clerkId, verifiedContacts);
    } catch (error) {
      attachFailed = true;
      console.log("claim-seller-application: attach failed:", logCode(error));
    }
  }

  const result = await claimAttached(client, clerkId);
  if (attachFailed && !result.claimed) {
    throw new Error("attach_failed");
  }
  return result;
}

/// The claim of the oldest approved application attached to the account.
async function claimAttached(
  client: ClaimClient,
  clerkId: string,
): Promise<{ claimed: boolean; reason?: string }> {
  const row = await findClaimable(client, clerkId);
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
