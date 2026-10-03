# 0012. Use one Supabase project and one Clerk instance for both apps, with sellers as a role (decision history)

## Context

Spec 0011 chose two separate Supabase projects and two Clerk instances, joined by Edge Functions, and recorded that choice as its riskiest part. Every seller service named (delivery tracking, messages, posts) has a buyer on the other end, so each one would have become a copy job between two databases that can lag, fail or disagree. One developer would own two schemas, two sets of rules, two migration histories and the sync code.

The code already points the other way. `user_profiles.role` allows `buyer` or `seller`. Sellers are public rows that buyers see on store pages. Every owned table is keyed on the Clerk `sub` (the user id inside the sign in token). The catalog (`products`, `reels`) is read only for clients today, so there is no seller write path yet.

Two things in the current schema must change before sellers can write anything. First, `insert own profile` and `update own profile` let a signed in client write any column of its own row, including `role`, `is_verified` and the cached counters, so anyone could promote or verify themselves. Second, the column default for `role` is `'seller'`, and the buyer app's sign in step writes `role: 'buyer'` on every sign in, which would silently turn a seller back into a buyer.

This decision is repo wide. It touches the backend folder, both apps and the docs, and it changes decisions in spec 0011 that are not built yet.

## Options considered

### Option 1: One Supabase project and one Clerk instance, sellers as a role

Both apps use the same backend. Seller access is controlled by `role` and row level rules.

**Pros**:
- No sync code, no lag between databases, and a seller's store row is the same row buyers read.
- One account per person, even for someone who buys and sells.
- One schema, one set of rules, one migration history for one developer.

**Cons**:
- One bad rule or migration can affect both apps.
- Seller and buyer data share one database, so the rules must be right (the role lock below).
- Both apps depend on one Clerk configuration, including the beta Clerk packages.

### Option 2: Two Supabase projects and two Clerk instances, joined by Edge Functions (spec 0011)

**Pros**:
- Hard isolation between the two audiences.
- Each backend can change on its own.

**Cons**:
- Every shared fact needs a sync that can lag or fail.
- A seller account has no row in the buyer project until the sync creates one.
- Two sets of everything for one developer, and a person who both buys and sells needs two accounts.

### Option 3: One Supabase project, two Clerk instances

**Pros**:
- Separate sign in screens and user lists per app.

**Cons**:
- Two identities for one person, so a seller who buys has two ids to link.
- Two Clerk instances to configure and keep in step (settings, sign in methods, webhooks), and the Supabase side must trust both.

## Rationale

The deciding forces are one developer, the buyer on the other end of every seller service, and a schema that already models sellers as a role. Option 2 solves isolation, which a single developer does not need, and pays for it with sync code on every shared fact. Option 3 keeps the sync problem away but splits identity, which breaks the common case of a seller who also buys. Option 1 is also the cheapest to undo later: if one audience needs its own backend, a service can be split out behind an API then, with real traffic numbers to guide it.

The cost is the shared blast radius, which is why this spec makes the role lock part of the same change. Opening seller writes while any client can still set its own `role` would let anyone become a seller and verify themselves.
