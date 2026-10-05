# 0014 rationale: one login, a store area in the buyer app, and applications from visitors

## Context

> ⚠️ Premise note: two things in this design are riskier than they look. First, applications from people with no account reverse spec 0013's rule that every application belongs to a signed in account, so the one place that proved who sent the photos is gone. The new path is an open write door protected only by rate limits, and it stores ID photos of people we cannot yet identify. Second, spec 0011 recorded that the seller app is its own product, and this spec turns that into one app. That is a real reversal, so it is written down here instead of slipping in through a UI change.

The Figma file draws one onboarding for everyone: a landing screen with Sign up, Log in and "Interested in becoming a seller ? Apply now", and a Log in screen with a Buyer or Store owner choice. The buyer app already builds those screens. The Store owner choice only changes the screen, and "Apply now" does nothing. Spec 0011 says the seller app is a separate app with its own sign in, and spec 0012 moved both apps onto one Supabase project and one Clerk instance with sellers as a role on the profile. Spec 0013 added an application that a signed in buyer sends and an admin approves. Its last task, the seller app gate, assumes the separate seller app.

The owner wants the choice made at login to decide what a person sees, and wants people who have no account to be able to apply. A Clerk session does not move between two installed apps, so two apps would make a store owner sign in a second time. The seller features themselves (products, reels, orders) are not built or scoped yet, so the store area has nothing real to show.

There is already a way to get an anonymous session in the buyer app (every visitor has one), and the project already runs a Clerk verified Edge Function for account deletion. A person who applies without an account has to be linked to the account they create later. The app already runs a step at sign in, `merge_anonymous_identity`, that proves the anonymous session on the phone belongs to the person who is signing in.

Not deciding leaves the Store owner choice and the "Apply now" link as decoration, and leaves 0013's task 6 pointing at an app that the login can never reach.

## Options considered

### Option 1: One app with a role switched store area, visitor applications in the same table, claimed on sign in

The buyer app holds both areas. The login choice and the profile role pick the area, a toggle switches between them for approved sellers, and `apps/seller` is removed. A visitor applies through their anonymous session into the same table with private contact columns. When the same phone signs up or logs in, the application is attached to that account, and an Edge Function turns an approved, attached application into a seller.

**Pros**:
- One install, one login, no second sign in. It matches the shared onboarding in the design.
- Reuses the screens, the anonymous session, the table and the approve and reject functions that exist.
- Approval stays the only manual step for the admin.

**Cons**:
- Opens a write path to people with no account.
- Reverses 0011's separate seller app. Every buyer gets the store area code, and one release carries both audiences.
- More moving parts: new columns, two service functions, a changed `merge_anonymous_identity` and an Edge Function.
- A person who applies on one phone and signs up on another is not attached automatically.

### Option 2: Two apps, the buyer app hands a Store owner off to the seller app

`apps/seller` stays its own store listing. Choosing Store owner on the buyer app's login opens the seller app, where the person signs in again.

**Pros**:
- Keeps 0011's separation and separate store listings.
- Buyers never download seller code.

**Cons**:
- The Clerk session does not carry over, so a store owner signs in twice, and the onboarding exists in two apps.
- Needs deep links and a second install for every seller, and a way to find the seller app from the buyer app.
- The login screen's Store owner choice would mostly mean "go install another app".

### Option 3: One app, but applicants must sign up first

Same app shape as Option 1. "Apply now" opens sign up, and the application is sent by the new account.

**Pros**:
- No open write path: every file and row belongs to a verified account, and the 0013 rules stay exactly as they are.
- Far less to build: no new columns, bucket, functions or claim.

**Cons**:
- Asks a curious person to create an account before they can even try applying, which the owner did not want.
- Does not match the "Apply now" link, which sits beside Sign up as a separate choice.

### Option 4: Option 1, with a captcha on submit and a manual link by the admin

Visitors submit through an Edge Function that checks a captcha, and after approval the admin links every application to the account by running a function with the Clerk user id.

**Pros**:
- A captcha is a stronger spam brake than rate limits.
- No attach step and no claim at sign in.

**Cons**:
- A captcha step in the app, a new secret and a third party dependency.
- A manual step for every approval until the admin dashboard exists, and a chance to link the wrong account.

## Rationale

Option 1 follows the owner's flow and the forces above. The design draws one login for both roles, a Clerk session cannot move between two apps (Option 2 would force a second sign in and a second onboarding), and nothing in the store area exists yet, so keeping seller code in the buyer app costs almost nothing today. The owner chose to accept the reversal of 0011, so it is recorded openly. Option 3 is the safest and the cheapest, but the owner wants visitors to apply without an account, and the "Apply now" link sits beside Sign up as its own choice.

For the visitor path, the anonymous session the app already has is enough to bind a submit to one session without any new service. The risk is real, so the design stacks cheap brakes: one open application per session, per email and per phone, a private bucket nobody can read, a 12 file and 5 MB cap per session and Supabase's own anonymous sign in rate limit. A captcha and a manual link (Option 4) would be stronger, and the follow up list keeps the captcha as the next step if spam appears.

How an application finds its account is the part the cross check changed. The first draft matched an approved application to whoever signed up with a verified email or phone equal to what the visitor typed. A read only review on a second model showed why that is unsafe: a visitor can type a victim's email and their own phone, the admin confirms the phone and approves, and the victim's next sign in hands them the store and overwrites their profile. A typo does the same to a stranger. So nothing the visitor types is ever used to match. The application attaches only to the account created or used on the phone that sent it, proved by the anonymous session that `merge_anonymous_identity` already checks at sign in. The cost is that a person who applies on one phone and signs up on another is not attached automatically, and the admin attaches that case by hand, which is rare and safe. The claim itself still runs in an Edge Function, because it has to copy the logo between buckets (the service role and the Storage API), and it now also runs on launch, resume and when the Seller application screen opens, so an approval that comes weeks after sign up is not missed.

The cross check also led to a username reservation for approved but unclaimed applications, phone numbers stored in international format, a cap on files per anonymous session, row locks in the claim, a fixed logo destination so a retry cannot fail, and a deletion order that reads the file paths before the rows go.

The engineer's choices that shaped this: one app, switched by role (not a handoff); the last area remembered; a non seller who picks Store owner goes to the buyer area with a notice (so the waiting and blocked screens from 0013 are not needed); a toggle at the top of both areas, shown only to approved sellers; visitors apply with name, email and phone and no account; contact details are not verified before sending; the logo is uploaded privately and copied on claim; and rejected or unclaimed applications are kept 30 days. The engineer first chose to claim by verified email or phone, and this spec replaces that with the same phone binding after the cross check found the takeover risk. The recommended pick was followed in every other case except the 30 day retention (the recommended pick was 90 days) and the logo (the recommended pick was to skip it for visitors). Both cost a little more to build or to run than the recommended options, and both are recorded as the owner's choice.
