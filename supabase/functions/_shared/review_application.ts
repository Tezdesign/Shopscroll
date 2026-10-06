// Decision record: docs/specs/_root/0016-seller-application-admin-email/index.md
// (AC-4 to AC-8, AC-11, AC-13, build plan task 4)
//
// What the review page asks for. With the token from the email it can view the
// application (details and fresh short links to the photos) and approve or
// reject it. The token is checked here and again inside
// `decide_application_with_token`, which claims it and decides in one
// transaction. An unknown, expired or used token gets the same answer
// (`invalid_link`, 404), so the page learns nothing about which it was.
//
// Kept apart from `review-application/index.ts` and free of any Deno or npm
// import, so a test can run it against fakes.

import { hashToken } from "./admin_email.ts";
import type { ApplicationDetails } from "./application_loader.ts";

export const PHOTO_LINK_SECONDS = 300;
export const MAX_REASON_LENGTH = 500;

export interface TokenRow {
  applicationId: string;
  usedAt: string | null;
  expiresAt: string;
}

export interface ReviewDeps {
  findToken(tokenHash: string): Promise<TokenRow | null>;
  load(applicationId: string): Promise<ApplicationDetails | null>;
  /// A signed link that lasts `seconds`, or null when the file is not there.
  signedUrl(bucket: string, path: string, seconds: number): Promise<string | null>;
  /// `decide_application_with_token`: 'approved', 'rejected' or 'not_reviewing',
  /// or throws an Error whose message is the refusal (invalid_link,
  /// reason_required, already_seller, username_taken, not_found).
  decide(tokenHash: string, action: "approve" | "reject", reason: string | null): Promise<string>;
  now(): Date;
}

export interface ReviewAnswer {
  status: number;
  body: Record<string, unknown>;
}

const INVALID_LINK: ReviewAnswer = { status: 404, body: { error: "invalid_link" } };

function isImage(path: string): boolean {
  return /\.(jpe?g|png)$/i.test(path);
}

/// Where each file of the application lives. A visitor's three files are in
/// `visitor-documents`. An account's ID and business document are in
/// `application-documents` and its logo in `store-logos` (specs 0013 and 0014).
function photoSlots(app: ApplicationDetails): { kind: string; bucket: string; path: string }[] {
  const visitor = app.origin === "visitor";
  const slots = [
    { kind: "id", bucket: visitor ? "visitor-documents" : "application-documents", path: app.idDocumentPath },
  ];
  if (app.businessDocumentPath) {
    slots.push({
      kind: "business",
      bucket: visitor ? "visitor-documents" : "application-documents",
      path: app.businessDocumentPath,
    });
  }
  if (app.logoPath) {
    slots.push({ kind: "logo", bucket: visitor ? "visitor-documents" : "store-logos", path: app.logoPath });
  }
  return slots;
}

/// A token that is known, not used and not expired, or null.
async function validToken(
  deps: ReviewDeps,
  token: unknown,
): Promise<{ hash: string; row: TokenRow } | null> {
  if (typeof token !== "string" || token.length < 20 || token.length > 100) return null;
  const hash = await hashToken(token);
  const row = await deps.findToken(hash);
  if (!row || row.usedAt || new Date(row.expiresAt) <= deps.now()) return null;
  return { hash, row };
}

/// Maps the database's refusal to an answer the page can show.
function refusal(message: string): ReviewAnswer {
  switch (message) {
    case "invalid_link":
    case "not_found":
      return INVALID_LINK;
    case "reason_required":
      return { status: 422, body: { error: "reason_required" } };
    case "already_seller":
    case "username_taken":
      return { status: 409, body: { error: message } };
    default:
      return { status: 500, body: { error: "failed" } };
  }
}

/// Handles one request body from the review page. Never throws.
export async function handleReview(deps: ReviewDeps, body: unknown): Promise<ReviewAnswer> {
  const request = (body && typeof body === "object" ? body : {}) as Record<string, unknown>;
  const action = request.action;
  if (action !== "view" && action !== "approve" && action !== "reject") {
    return { status: 400, body: { error: "bad_request" } };
  }

  try {
    const checked = await validToken(deps, request.token);
    if (!checked) return INVALID_LINK;

    if (action === "view") {
      const app = await deps.load(checked.row.applicationId);
      if (!app) return INVALID_LINK;
      const photos = [];
      for (const slot of photoSlots(app)) {
        const url = await deps.signedUrl(slot.bucket, slot.path, PHOTO_LINK_SECONDS);
        if (url) photos.push({ kind: slot.kind, url, image: isImage(slot.path) });
      }
      return {
        status: 200,
        body: {
          application: {
            origin: app.origin,
            status: app.status,
            storeName: app.storeName,
            username: app.username,
            location: app.location,
            bio: app.bio,
            websiteUrl: app.websiteUrl,
            contactPhone: app.contactPhone,
            contactEmail: app.contactEmail,
            createdAt: app.createdAt,
            applicantName: app.applicantName,
            applicantEmail: app.applicantEmail,
            applicantPhone: app.applicantPhone,
          },
          photos,
        },
      };
    }

    let reason: string | null = null;
    if (action === "reject") {
      reason = typeof request.reason === "string" ? request.reason.trim() : "";
      if (reason.length < 1 || reason.length > MAX_REASON_LENGTH) {
        return { status: 422, body: { error: "reason_required" } };
      }
    }

    const outcome = await deps.decide(checked.hash, action, reason);
    if (outcome === "not_reviewing") {
      return { status: 409, body: { error: "already_decided" } };
    }
    return { status: 200, body: { status: outcome } };
  } catch (error) {
    return refusal(error instanceof Error ? error.message : "");
  }
}
