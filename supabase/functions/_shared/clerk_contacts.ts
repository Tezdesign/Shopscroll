// Decision record: docs/specs/_root/0014-shared-login-seller-area/index.md
// (AC-12, build plan task 12)
//
// The email addresses and phone numbers Clerk has verified for one user, read
// through the Clerk Backend API with the secret key. Only a contact whose
// verification status is `verified` is returned: an unverified one proves nothing
// about who owns it. Any failure throws, so the caller attaches nothing and tries
// again later.
//
// Free of any Deno or npm import (the fetch is injected), so a test can run it
// against a fake.

export const CLERK_USERS_URL = "https://api.clerk.com/v1/users/";

export interface VerifiedContacts {
  emails: string[];
  phones: string[];
}

function verified(list: unknown, key: string): string[] {
  if (!Array.isArray(list)) throw new Error("clerk_bad_answer");
  return list
    .filter((item) =>
      item?.verification?.status === "verified" && typeof item[key] === "string"
    )
    .map((item) => item[key] as string);
}

export async function verifiedContacts(
  fetchFn: typeof fetch,
  secretKey: string,
  clerkId: string,
): Promise<VerifiedContacts> {
  const response = await fetchFn(
    `${CLERK_USERS_URL}${encodeURIComponent(clerkId)}`,
    { headers: { Authorization: `Bearer ${secretKey}` } },
  );
  if (!response.ok) throw new Error(`clerk_http_${response.status}`);
  const body = await response.json();
  return {
    emails: verified(body?.email_addresses, "email_address"),
    phones: verified(body?.phone_numbers, "phone_number"),
  };
}
