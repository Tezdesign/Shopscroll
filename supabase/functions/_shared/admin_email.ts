// Decision record: docs/specs/_root/0016-seller-application-admin-email/index.md
// (AC-1, AC-2, AC-3, AC-9, AC-10, build plan task 3)
//
// Builds the email about a new seller application and sends it through Mailjet.
// The email holds the store and contact details and one private review link, and
// never a photo or a photo link. Everything a person typed is escaped.
//
// Kept apart from `notify-admin-application/index.ts` and free of any Deno or npm
// import, so a test can run it against fakes. It only uses `crypto`, `btoa` and
// `fetch`, which Deno and Node both provide.

/// What the email is built from: one application, plus the applicant's contact
/// details (from the application for a visitor, from the profile for an account).
export interface ApplicationEmailData {
  id: string;
  origin: "account" | "visitor";
  status: string;
  adminNotifiedAt: string | null;
  storeName: string;
  username: string;
  location: string;
  bio: string | null;
  websiteUrl: string | null;
  contactPhone: string | null;
  contactEmail: string | null;
  createdAt: string;
  applicantName: string | null;
  applicantEmail: string | null;
  applicantPhone: string | null;
}

export interface MailjetMessage {
  From: { Email: string; Name: string };
  To: { Email: string }[];
  Subject: string;
  TextPart: string;
  HTMLPart: string;
  CustomID: string;
  TrackClicks: "disabled";
  TrackOpens: "disabled";
}

export const REVIEW_LINK_DAYS = 7;
export const MAILJET_SEND_URL = "https://api.mailjet.com/v3.1/send";

export function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

/// One line of plain text: control characters and line breaks become a space.
export function oneLine(value: string, max = 100): string {
  const spaced = [...value].map((ch) => {
    const code = ch.charCodeAt(0);
    return code < 32 || code === 127 || code === 0x2028 || code === 0x2029 ? " " : ch;
  }).join("");
  return spaced.replace(/ {2,}/g, " ").trim().slice(0, max);
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

/// A new random token, 32 bytes, URL safe. Only its hash is ever stored.
export function newToken(): string {
  return base64Url(crypto.getRandomValues(new Uint8Array(32)));
}

/// SHA-256 of the token as lower case hex, the value stored and looked up.
export async function hashToken(token: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(token),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

/// Compares two secrets without stopping at the first different character. Both
/// are hashed first, so the lengths never differ.
export async function secretsMatch(a: string, b: string): Promise<boolean> {
  const [x, y] = await Promise.all([hashToken(a), hashToken(b)]);
  let difference = 0;
  for (let i = 0; i < x.length; i++) {
    difference |= x.charCodeAt(i) ^ y.charCodeAt(i);
  }
  return difference === 0;
}

/// The link in the email. The token sits in the fragment (after `#`), so the page
/// host and its logs never see it.
export function buildReviewLink(reviewPageUrl: string, token: string): string {
  return `${reviewPageUrl.split("#")[0]}#t=${token}`;
}

function detailLines(data: ApplicationEmailData): [string, string][] {
  const rows: [string, string | null][] = [
    ["Kind", data.origin === "visitor" ? "Visitor, no account" : "Signed in account"],
    ["Store name", data.storeName],
    ["Username", data.username],
    ["Location", data.location],
    ["About", data.bio],
    ["Website", data.websiteUrl],
    ["Store phone", data.contactPhone],
    ["Store email", data.contactEmail],
    ["Applicant name", data.applicantName],
    ["Applicant email", data.applicantEmail],
    ["Applicant phone", data.applicantPhone],
    ["Sent", data.createdAt],
  ];
  return rows.filter((row): row is [string, string] => !!row[1]);
}

/// The Mailjet message for one application. Click and open tracking are off:
/// with tracking on, Mailjet rewrites the link and stores the whole address,
/// token included.
export function buildMailjetMessage(
  data: ApplicationEmailData,
  link: string,
  sender: string,
  admin: string,
): MailjetMessage {
  const rows = detailLines(data);
  const text = [
    "A new seller application is waiting for a decision.",
    "",
    ...rows.map(([label, value]) => `${label}: ${value}`),
    "",
    `Review it (the link works for ${REVIEW_LINK_DAYS} days and shows the ID photos):`,
    link,
    "",
    `Application id: ${data.id}`,
  ].join("\n");
  const html = [
    "<p>A new seller application is waiting for a decision.</p>",
    "<table cellpadding=\"4\">",
    ...rows.map(([label, value]) =>
      `<tr><td><b>${escapeHtml(label)}</b></td><td>${escapeHtml(value)}</td></tr>`
    ),
    "</table>",
    `<p><a href="${escapeHtml(link)}">Review this application</a> ` +
    `(the link works for ${REVIEW_LINK_DAYS} days and shows the ID photos).</p>`,
    `<p style="color:#666">Application id: ${escapeHtml(data.id)}</p>`,
  ].join("\n");

  return {
    From: { Email: sender, Name: "Shopscroll" },
    To: [{ Email: admin }],
    Subject: `New seller application: ${oneLine(data.storeName)}`,
    TextPart: text,
    HTMLPart: html,
    CustomID: data.id,
    TrackClicks: "disabled",
    TrackOpens: "disabled",
  };
}

export type SendResult = { ok: true } | { ok: false; code: string };

/// Sends one message through the Mailjet v3.1 API. Success is HTTP 200 and
/// `Messages[0].Status` equal to `success`. A failure is a short code that holds
/// nothing personal.
export async function sendWithMailjet(
  fetchFn: typeof fetch,
  apiKey: string,
  apiSecret: string,
  message: MailjetMessage,
): Promise<SendResult> {
  let response: Response;
  try {
    response = await fetchFn(MAILJET_SEND_URL, {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${apiKey}:${apiSecret}`)}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ Messages: [message] }),
    });
  } catch {
    return { ok: false, code: "mailjet_network" };
  }
  if (!response.ok) return { ok: false, code: `mailjet_http_${response.status}` };
  try {
    const body = await response.json();
    return body?.Messages?.[0]?.Status === "success"
      ? { ok: true }
      : { ok: false, code: "mailjet_status_error" };
  } catch {
    return { ok: false, code: "mailjet_bad_answer" };
  }
}

/// What the notify flow needs from the outside, so a test can stand in for it.
export interface NotifyDeps {
  load(id: string): Promise<ApplicationEmailData | null>;
  /// Takes the 2 minute lease (`claim_admin_notification`).
  claim(id: string): Promise<boolean>;
  saveToken(applicationId: string, tokenHash: string, expiresAt: Date): Promise<void>;
  markNotified(id: string): Promise<void>;
  markError(id: string, code: string): Promise<void>;
  send(message: MailjetMessage): Promise<SendResult>;
  now(): Date;
}

export interface NotifyConfig {
  reviewPageUrl: string;
  sender: string;
  admin: string;
}

/// Emails the admin about one application, once. Idempotent: an application that
/// is already notified, no longer under review, or leased by another call sends
/// nothing. A failure leaves `admin_notified_at` empty and saves a short code, so
/// the retry job tries again. Never throws.
export async function notifyAdmin(
  deps: NotifyDeps,
  config: NotifyConfig,
  applicationId: string,
): Promise<{ sent: boolean; reason?: string }> {
  try {
    const data = await deps.load(applicationId);
    if (!data) return { sent: false, reason: "not_found" };
    if (data.adminNotifiedAt) return { sent: false, reason: "already_sent" };
    if (data.status !== "reviewing") {
      // Decided before the email went out (for example in the SQL editor).
      await deps.markNotified(applicationId);
      return { sent: false, reason: "not_reviewing" };
    }
    if (!(await deps.claim(applicationId))) {
      return { sent: false, reason: "claimed" };
    }

    const token = newToken();
    const expiresAt = new Date(
      deps.now().getTime() + REVIEW_LINK_DAYS * 24 * 60 * 60 * 1000,
    );
    await deps.saveToken(applicationId, await hashToken(token), expiresAt);

    const result = await deps.send(
      buildMailjetMessage(
        data,
        buildReviewLink(config.reviewPageUrl, token),
        config.sender,
        config.admin,
      ),
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
