// Decision record: docs/specs/_root/0016-seller-application-admin-email/index.md
//
// Reads one seller application with the applicant's contact details, for the two
// admin email functions (`notify-admin-application` and `review-application`),
// so both show the same facts. For a visitor the details are on the application,
// for an account they come from the profile (the email from the application when
// the applicant gave one). Needs the service role client.

import type { ApplicationEmailData } from "./admin_email.ts";

/// The email's data plus the file paths the review page turns into short links.
export interface ApplicationDetails extends ApplicationEmailData {
  idDocumentPath: string;
  businessDocumentPath: string | null;
  logoPath: string | null;
}

// deno-lint-ignore no-explicit-any
type Client = any;

export async function loadApplicationDetails(
  supabase: Client,
  id: string,
): Promise<ApplicationDetails | null> {
  const { data: row, error } = await supabase
    .from("seller_applications")
    .select(
      "id, origin, status, admin_notified_at, store_name, username, location, bio, " +
        "website_url, contact_phone, contact_email, created_at, applicant_id, " +
        "applicant_name, applicant_email, applicant_phone, id_document_path, " +
        "business_document_path, logo_path",
    )
    .eq("id", id)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!row) return null;

  let name = row.applicant_name as string | null;
  let email = row.applicant_email as string | null;
  let phone = row.applicant_phone as string | null;
  if (row.origin === "account" && row.applicant_id) {
    const { data: profile } = await supabase
      .from("user_profiles")
      .select("name, email, phone")
      .eq("id", row.applicant_id)
      .maybeSingle();
    name = profile?.name ?? null;
    // The application's own private email (0017) wins over the profile email.
    email = (row.applicant_email as string | null) ?? profile?.email ?? null;
    phone = profile?.phone ?? null;
  }

  return {
    id: row.id,
    origin: row.origin,
    status: row.status,
    adminNotifiedAt: row.admin_notified_at,
    storeName: row.store_name,
    username: row.username,
    location: row.location,
    bio: row.bio,
    websiteUrl: row.website_url,
    contactPhone: row.contact_phone,
    contactEmail: row.contact_email,
    createdAt: row.created_at,
    applicantName: name,
    applicantEmail: email,
    applicantPhone: phone,
    idDocumentPath: row.id_document_path,
    businessDocumentPath: row.business_document_path,
    logoPath: row.logo_path,
  };
}
