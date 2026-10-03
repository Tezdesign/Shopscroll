# 0013. Require a reviewed seller application before a person becomes a seller (decision record)

## Context

> ⚠️ Premise note: spec 0012 left `become_seller()` open to any signed in person, so today the seller role is self service. This spec adds a review, but the review means nothing while that function stays callable. The right framing is that this feature and closing the function ship together. It is kept open for now at your request, so it is recorded as a launch blocker in the spec, not as done. Also, the Figma list screen says "Got more than one shop?", which implies several stores per account. The data model has one store per profile, so this spec builds one store per account and defers the rest.

The app has a buyer app and a seller app on one Supabase project and one Clerk instance (spec 0012). A profile has `role` `buyer` or `seller`, and only `become_seller()` or the service role can change it. Spec 0012 chose that sellers are a role, but it did not say who is allowed to become one. A marketplace usually wants to know who sells on it, so a seller needs to be checked before their products and reels appear to buyers.

Your Figma flow "Profile-seller" shows the buyer side of this: a "Seller application" row in Settings, an empty state, and a list where each application has a store name, a submitted date and a status such as "Reviewing". The form itself is not designed. You also want the person to upload identity or business documents, to be told the result in the app and by email (later), and to have an admin decide (the admin dashboard is later).

The workspace is repo wide: it touches the Supabase backend, the buyer app (the form and list), the seller app (the sign in gate) and the shared package. Applications hold personal data (a photo of an ID), so retention and access matter more than for the rest of the schema. The team is one developer.

## Options considered

### Option 1: An applications table, files in Supabase Storage, server side review by the service role

A `seller_applications` table holds the request, the files live in two Supabase Storage buckets, and three database functions submit, approve and reject. Clients can read their own rows only. Approval copies the store details onto the profile and sets the role.

**Pros**:
- Keeps one backend, with the history and the reason of every decision on record.
- All rules (one open application, username check, file ownership) are enforced in one place, the database.
- The later admin dashboard reuses the same functions.

**Cons**:
- Identity files are held in your own project, so you carry the data protection duty.
- No admin screen yet, so review is manual.
- Storage policies and a Clerk user id as the file owner need testing before the UI is built.

### Option 2: Keep self service, only fill a store profile form

Anyone becomes a seller at once and the "application" is just the store details form (the state after spec 0012).

**Pros**:
- Fastest, nothing to review, no personal data.

**Cons**:
- Anyone can sell, with no check. It does not match the "Reviewing" status in your design.

### Option 3: A status column on the profile, no applications table

Add `seller_status` to `user_profiles` (none, reviewing, approved, rejected) and keep the form fields on the profile.

**Pros**:
- One table fewer, simpler reads.

**Cons**:
- No history: a second application overwrites the first, and the rejection reason has nowhere clean to live.
- Mixes private application data (documents) into a publicly readable seller profile row.
- Blocks the multiple stores per account you may want later.

### Option 4: An outside identity check service

Send the ID photo to a verification provider and approve by its result.

**Pros**:
- Less manual review, fraud tooling built in.

**Cons**:
- A new vendor, cost per check and an extra integration for one developer. Premature before any volume exists.

## Rationale

The forces are one developer, a design that already shows a "Reviewing" state, personal data in the uploads, and a backend that spec 0012 made shared. Option 2 skips the review you asked for. Option 3 saves a table but loses history and mixes private data into a public row. Option 4 solves a scale problem you do not have. Option 1 reuses what is already running (Supabase, row level security, the `place_order` style functions) and keeps every rule in the database, which is where spec 0012 put the role.

Three smaller calls were made for you. The client creates the application id so a retry or a double tap sends one application and the same id names the file folder. Approve and reject are plain functions callable only by the service role, so the admin works today in the SQL editor and the dashboard later calls the same code, instead of building an admin role and screen now. Logos go to a public bucket because buyers must see them and a logo carries nothing sensitive, while documents stay private. The runner up for each: a server generated id (rejected, it cannot name the folder before the upload), an admin flag on the profile (more to build and lock down now), and a private logo copied on approval (needs an Edge Function for a small gain).

You chose to keep the ID files for as long as the account exists, over deleting them 30 days after a decision. That gives you a record for disputes but a longer duty to protect them, so the spec adds an account deletion step and a follow up to review data protection rules.
