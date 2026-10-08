# 0017. Rationale and options: email the applicant when a seller application is decided

## Context

> ⚠️ Premise note: the email you asked for says "create an account with the email you applied with". Today that would not work. Spec 0014 attaches an approved visitor application only to the account created on the **same phone** that sent it, and states that nothing a visitor types is ever used to match. Someone who applies on a laptop, loses the phone, or already has an account would get a congratulations email and then never become a seller. Rather than weaken the email, this spec adds a second, safe way to match: the account's **Clerk verified** email must equal the typed one, and only after an admin has approved. It deliberately changes that 0014 rule, and the cost is written in the Consequences.

Seller applications are decided by an admin, today from the review page in the admin email (0016) or the SQL editor. The applicant is told nothing. The status chip in the app changes only for people who have an account and open that screen, and a visitor with no account has no way to learn the result. Scope feature 21 planned both an in app notice and an email.

Three facts shape the design. First, a decision can be made from several places (the review page now, an admin dashboard later, the SQL editor), so the notice has to hang on the data change, not on one caller. Second, a visitor's address is typed and unproven, while the address on a Clerk account has been verified by a code or by a sign in provider. Third, an account application has no personal email at all: the form asks only for a public store email, and approval copies that into the profile, so the profile cannot be the source.

The project already runs the pieces needed: Mailjet, a database trigger with `pg_net`, a retry job with `pg_cron`, Vault, and an Edge Function pattern with a shared secret (0016). The claim function (0014) already verifies the Clerk session and uses the service role. The app already shows the Buyer or Store owner switch to sellers.

## Options considered

### Option 1: A trigger on the decision, a new notify function, and attach by verified email (chosen)

A trigger on the `reviewing` to `approved` or `rejected` change posts to `notify-applicant-decision`, which sends through Mailjet. A retry job and a lease cover failures, as in 0016. The claim function also asks Clerk for the caller's verified addresses and attaches approved visitor applications that match.

**Pros**:
- Covers every decision path with one hook, including the future dashboard.
- Reuses a pattern that already works end to end, with one new Vault entry and no new secret.
- The approval email's instructions are true on any device and for people who already have an account.
- Verified email plus an earlier admin approval keeps the new match safe.

**Cons**:
- More moving parts: a function, a trigger, a job, and a Clerk call in the claim.
- It changes a stated 0014 rule.

### Option 2: Send the email from the review function

`review-application` sends the email right after `decide_application_with_token` succeeds.

**Pros**:
- No trigger, no new job, less to deploy.

**Cons**:
- A decision made in the SQL editor or from a future dashboard sends nothing.
- A crash after the decision loses the email, and there is no retry.
- It couples the applicant notice to one caller.

### Option 3: One scheduled job only

One job every few minutes sends for every decided row that is still unsent. No trigger.

**Pros**:
- Nothing on the decision path, and one fewer database object.

**Cons**:
- Up to 5 minutes late for every email, and the engineer chose the trigger pattern in 0016. It is the first thing to switch to if the trigger proves fragile.

### Option 4: Keep the same phone rule and only reword the email

Send the same email but say "sign up on the phone you applied from".

**Pros**:
- No change to the 0014 trust rule, no Clerk call.

**Cons**:
- People who already have an account, or who apply on another device, never become sellers. This does not meet the engineer's stated need.

## Rationale

Option 1 is the only one that meets both parts of the request. A trigger fires for any decision path (Option 2 fails that), arrives within a minute (Option 3 is slower), and matching by verified email makes the email's two paths real (Option 4 fails that). The retry job, the lease and the secret check are copied from 0016 because they were already proven in this project, which keeps the new code small and the operations familiar.

The email match is safe enough for one admin and low volume because of two gates that must both hold. An admin has already approved the application after seeing the ID photos, and the claimant must prove control of the mailbox through Clerk, not just type it. The remaining risk, a visitor naming someone else's address, hands a willing mailbox owner a store profile with the wrong details, which is small, visible and fixable by the admin. The phone attach stays as the second route.

The recipient rule follows the engineer's choice: the store contact email, plus a new optional personal email on the signed in form, stored in the column visitors already use. A fallback to the Clerk login email would always find an address but needs another Clerk call on every send, so it is left as a follow up. The applicant is told only what they need (the store name, the next step, the reason on a rejection), never photos, phone numbers or links, so a forwarded email gives away nothing.
