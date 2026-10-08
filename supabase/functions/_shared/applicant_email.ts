// Decision record: docs/specs/_root/0017-applicant-decision-email/index.md
// (AC-1 to AC-6, AC-12, AC-13, build plan task 3)
//
// Builds the email an applicant gets when a seller application is approved or
// rejected, and sends it through Mailjet. The recipient comes from the
// application row only, never from a profile. The email holds no photo, no ID
// data, no phone number and no link, and everything a person typed is escaped.
//
// Kept apart from `notify-applicant-decision/index.ts` and free of any Deno or
// npm import, so a test can run it against fakes. The Mailjet call, the secret
// check and the escape helpers are the ones `admin_email.ts` already has.

import {
  escapeHtml,
  type MailjetMessage,
  oneLine,
  type SendResult,
} from "./admin_email.ts";

/// What the email is built from: the decided application row.
export interface ApplicantEmailData {
  id: string;
  origin: "account" | "visitor";
  status: string;
  applicantNotifiedAt: string | null;
  storeName: string;
  rejectionReason: string | null;
  applicantEmail: string | null;
  contactEmail: string | null;
}

/// The address to write to: `applicant_email` for a visitor row, and for an
/// account row `applicant_email` when given, else the public store email.
export function recipientFor(data: ApplicantEmailData): string | null {
  const own = data.applicantEmail?.trim();
  const address = data.origin === "visitor"
    ? own
    : own || data.contactEmail?.trim();
  return address ? address : null;
}

const SWITCH_PATH =
  "open the app and use the Buyer or Store owner switch at the top of the Profile tab";

function approvedBody(
  data: ApplicantEmailData,
  store: string,
  address: string,
): { text: string[]; html: string[] } {
  if (data.origin === "visitor") {
    const text = [
      `Congratulations! Your application for ${store} was approved.`,
      "",
      "What to do next:",
      `New here? Create an account with exactly this email address: ${address}. Confirm it with the code Clerk sends you, or sign in with a provider that uses it. Your application is attached to your account on its own and you become a store owner.`,
      `Already have an account with this email? Just ${SWITCH_PATH}.`,
    ];
    const html = [
      `<p>Congratulations! Your application for <b>${escapeHtml(store)}</b> was approved.</p>`,
      "<p><b>What to do next</b></p>",
      `<p>New here? Create an account with exactly this email address: <b>${escapeHtml(address)}</b>. Confirm it with the code Clerk sends you, or sign in with a provider that uses it. Your application is attached to your account on its own and you become a store owner.</p>`,
      `<p>Already have an account with this email? Just ${SWITCH_PATH}.</p>`,
    ];
    return { text, html };
  }
  return {
    text: [
      `Congratulations! Your application for ${store} was approved.`,
      "",
      `Your account is now a store owner account. To start selling, ${SWITCH_PATH}.`,
    ],
    html: [
      `<p>Congratulations! Your application for <b>${escapeHtml(store)}</b> was approved.</p>`,
      `<p>Your account is now a store owner account. To start selling, ${SWITCH_PATH}.</p>`,
    ],
  };
}

function rejectedBody(
  data: ApplicantEmailData,
  store: string,
): { text: string[]; html: string[] } {
  const reason = (data.rejectionReason ?? "").trim();
  const again =
    "You can send a new application. Tap Apply now if you have no account, or open Settings and then Seller application if you do.";
  return {
    text: [
      `Your application for ${store} was not approved.`,
      "",
      "Reason:",
      reason,
      "",
      again,
    ],
    html: [
      `<p>Your application for <b>${escapeHtml(store)}</b> was not approved.</p>`,
      "<p><b>Reason</b></p>",
      `<p>${escapeHtml(reason).replaceAll("\n", "<br>")}</p>`,
      `<p>${again}</p>`,
    ],
  };
}

/// The Mailjet message for one decided application. Click and open tracking are
/// off, and replies go to the admin.
export function buildApplicantMessage(
  data: ApplicantEmailData,
  address: string,
  sender: string,
  admin: string,
): MailjetMessage {
  const store = oneLine(data.storeName);
  const approved = data.status === "approved";
  const body = approved
    ? approvedBody(data, store, address)
    : rejectedBody(data, store);
  return {
    From: { Email: sender, Name: "Shopscroll" },
    To: [{ Email: address }],
    ReplyTo: { Email: admin },
    Subject: approved
      ? `Your Shopscroll application for ${store} was approved`
      : `Your Shopscroll application for ${store} was not approved`,
    TextPart: body.text.join("\n"),
    HTMLPart: body.html.join("\n"),
    CustomID: data.id,
    TrackClicks: "disabled",
    TrackOpens: "disabled",
  };
}

/// What the notify flow needs from the outside, so a test can stand in for it.
export interface ApplicantNotifyDeps {
  /// Reads the row itself, never through a profile.
  load(id: string): Promise<ApplicantEmailData | null>;
  /// Takes the 2 minute lease (`claim_applicant_notification`).
  claim(id: string): Promise<boolean>;
  markNotified(id: string): Promise<void>;
  markError(id: string, code: string): Promise<void>;
  send(message: MailjetMessage): Promise<SendResult>;
}

export interface ApplicantNotifyConfig {
  sender: string;
  admin: string;
}

/// Emails the applicant about one decision, once. Idempotent: an application
/// that is already notified, not decided, or leased by another call sends
/// nothing. No address saves `no_recipient`, which the retry job skips. A failure
/// leaves `applicant_notified_at` empty and saves a short code, so the retry job
/// tries again. Never throws.
export async function notifyApplicant(
  deps: ApplicantNotifyDeps,
  config: ApplicantNotifyConfig,
  applicationId: string,
): Promise<{ sent: boolean; reason?: string }> {
  try {
    const data = await deps.load(applicationId);
    if (!data) return { sent: false, reason: "not_found" };
    if (data.applicantNotifiedAt) return { sent: false, reason: "already_sent" };
    if (data.status !== "approved" && data.status !== "rejected") {
      return { sent: false, reason: "not_decided" };
    }
    const address = recipientFor(data);
    if (!address) {
      await deps.markError(applicationId, "no_recipient");
      return { sent: false, reason: "no_recipient" };
    }
    if (!(await deps.claim(applicationId))) {
      return { sent: false, reason: "claimed" };
    }

    const result = await deps.send(
      buildApplicantMessage(data, address, config.sender, config.admin),
    );
    if (!result.ok) {
      await deps.markError(applicationId, result.code);
      return { sent: false, reason: result.code };
    }
    await deps.markNotified(applicationId);
    return { sent: true };
  } catch {
    try {
      await deps.markError(applicationId, "internal_error");
    } catch { /* nothing more to do */ }
    return { sent: false, reason: "internal_error" };
  }
}
