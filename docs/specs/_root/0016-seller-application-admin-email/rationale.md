# 0016. Rationale and options: email each new seller application to the admin through Mailjet

## Context

Seller applications (0013) and visitor applications (0014) land in `seller_applications` with status `reviewing`. Today nobody is told. The admin has to open the database, look for new rows, open the private ID photos in the Storage page and run `approve_seller_application` or `reject_seller_application` by hand. That works for a test, not for a launch, and a visitor who applies with no account waits with no sign that anyone saw it.

The engineer chose Mailjet as the email provider, one admin address, and an email on each new application only. The email has to carry enough to judge the application, but ID photos, a name, an email and a phone are personal data of people who may never create an account, so what goes into an inbox is a data protection choice. The engineer also wants the admin to decide from the email itself.

The platform adds two limits. A link that decides on its own is dangerous, because mail scanners and previews open links automatically. And Supabase Edge Functions cannot serve an HTML page on their default address: browsers receive the page as plain text unless a paid custom domain is used. The project has no admin role, no admin dashboard (scope feature 20) and no applicant notice (feature 21) yet.

> ⚠️ Premise note: a one tap decision link is a bearer credential. Anyone who gets the email can approve a seller, and the record cannot say who. This is accepted on purpose for the first version (one admin, one inbox), with expiry, hashing and an open page instead of an action on open to keep the risk small. The proper answer is an admin role and the dashboard in feature 20.

## Options considered

### Option 1: Database trigger, two Edge Functions and a static review page with one time tokens (chosen)

A trigger on `seller_applications` posts to `notify-admin-application`, which builds the email and calls Mailjet. A retry job covers failures. The email has one link to a static page on Cloudflare Pages. The page calls `review-application` to show the details and fresh short photo links, and to approve or reject with a token that is stored hashed and marked used.

**Pros**:
- Covers account and visitor applications even when the app is closed, and lives in a migration.
- Photos never leave Storage except as links that last 5 minutes.
- Reuses the 0013 decision functions, so no rule is duplicated.
- Stateful tokens give a clear used, expired and audit state.

**Cons**:
- Most moving parts: two functions, a token table, `pg_net`, `pg_cron`, Vault and a second host.
- Bearer link, so the inbox is the credential.

### Option 2: Trigger and email only, decide with the SQL editor

The same trigger and email, but the email lists the application id and the two SQL lines. No token table, no page, no second host.

**Pros**:
- Smallest build, nothing new to secure beyond the email.
- No bearer link.

**Cons**:
- The admin still needs a laptop and the SQL editor, and photos must be opened by hand in the dashboard.
- Does not meet the engineer's wish to decide from the email.

### Option 3: The app calls the function after Send

The Flutter app calls an Edge Function when the Send button succeeds.

**Pros**:
- No database trigger, `pg_net` or Vault.

**Cons**:
- A closed app or a dropped connection means no email, and anyone can call the function to spam the admin.
- Account and visitor paths need two call sites in the app.

### Option 4: Cron only, no trigger

One scheduled job every minute calls the notify function, which sends for every unsent `reviewing` row. This came out of the cross check.

**Pros**:
- No trigger, no Vault read inside a trigger, no race between a trigger and the job, and nothing at all on the submit path.

**Cons**:
- The email can arrive up to a minute late, and the engineer chose a trigger. It is the first thing to switch to if the trigger proves fragile.

### Option 5: Decision links that act on open

The email has Approve and Reject links that decide as soon as they are opened.

**Pros**:
- Fastest for the admin.

**Cons**:
- A mail scanner, a link preview or a mis-tap decides an application, and Reject has no place to enter the reason the database requires.

## Rationale

Option 1 is the only one that meets all of the engineer's stated needs: it fires on every application whatever the app does (Option 3 fails that), it keeps ID photos out of the inbox, and it lets the admin decide without a laptop (Option 2 fails that). Opening the link only shows the page, and the decision is a button press, because mail scanners open links (Option 4 fails that). The decision still runs through the 0013 functions, so there is one place where the rules live.

The engineer chose stored one time tokens over the stateless signed token I recommended. I accept it: it costs one table and a cleanup in the retry job, and in return a used or expired link is a recorded state, not something to infer. The static page on Cloudflare Pages follows from the Edge Function limit on HTML, and it keeps the token in the URL fragment so neither the page host nor any access log sees it. The retry job and the compare and set claim follow from the engineer's choice to retry failures, and keep it safe when the trigger and the job run close together.

The cost is operations: this adds a second host, three Supabase features (`pg_net`, `pg_cron`, Vault) and two secrets to set by hand. For one admin and low volume that is acceptable, and the dashboard in scope feature 20 can replace the page later without touching the notification path.
