# lib/features/seller_application

The buyer side of becoming a seller (specs 0013 and 0014). Nothing here approves anyone: an admin decides with the
service role, and only an approval (account applications) or a claim (visitor applications) sets `role = 'seller'`.

## Files

- `seller_application_screen.dart` — Settings, Seller application (Figma 3001:9520, 3001:9544): the person's
  applications with a status chip, and "Submit an application" for a buyer with none under review.
- `seller_application_wizard_screen.dart` — the form. Four steps for a signed in person (store details, contact and
  logo, documents, review). With `isVisitor: true` (route `/apply`, from "Apply now" on the welcome and Log in screens) it
  has an extra "About you" step (name, email, phone with the country picker, stored in international format) and ends on
  a confirmation instead of closing. Photos are uploaded only on Send, one by one, and an upload that worked is not
  repeated on a retry. The application id is made once, so a retry or a double tap sends one application.
- `seller_application_logic.dart` — field checks that mirror the SQL functions (the server is the truth), photo type and
  size checks, and the failure messages.

## Conventions

- Repository (`lib/data/repositories/seller_application_repository.dart`): `submit` with an `applicant`
  (`ApplicantContact`) calls `submit_visitor_application`, without one `submit_seller_application`. `uploadPhoto` with
  `asVisitor` stores all three photos in the private `visitor-documents` bucket as
  `<session id>/<application id>/<kind>-<name>`; a signed in person's logo goes to `store-logos` and the documents to
  `application-documents`. Every upload uses a new random name, because clients can never update or delete files.
- `SellerApplication.applicantId` is null for a visitor row that is attached to the account but not claimed yet.
- `sellerApplicationsProvider` asks the claim function first (see `lib/core/area/AGENTS.md`).
- Photos: JPEG or PNG, 5 MB, resized by the picker (max width 1600, quality 85).

Governing specs: `docs/specs/_root/0013-seller-application-request/index.md`,
`docs/specs/_root/0014-shared-login-seller-area/index.md`.

_Drafted by /sync from the introducing change, worth a quick human pass._
