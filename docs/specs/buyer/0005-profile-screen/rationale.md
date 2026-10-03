# 0005. Build the real Profile screen: rationale

## Context

The Profile tab has shown `ComingSoonScreen`, a generic "not built yet" placeholder, since the app's
navigation shell was first built. Spec 0004 (Clerk sign in) built a working `AccountScreen` with
sign out and delete account, but explicitly kept it unlinked from navigation, since designing the
real Profile tab was called out as a separate, later decision (its own Follow up item).

The Figma design for this page is far bigger than sign out and delete account. It includes rows for
several features that have no design or backend of their own yet in this buyer side only app:
becoming a seller, following stores, a delivery address book, saved payment methods, a support
contact form, a reports list, and static legal pages. Building every one of those for real is well
outside cloning one page. The forces at play are: matching the design faithfully so the page looks
and feels finished, giving people a real, working way to manage the parts of their account that
already exist (sign in state, name, username, bio), and being honest that most of the remaining rows
are not functional yet rather than silently dropping them from the design.

The page also assumes someone is already signed in (a name, a photo, a log out row). Today, nothing
in the app requires a real account, by design (spec 0004's welcome screen can always be skipped).
The Profile tab has to keep working for an anonymous browser too, without turning into a login wall.

## Options considered

### Option 1: Extend the existing `AccountScreen` in place

Add every new row directly onto the current `AccountScreen` file, keeping its existing shape (sign
out and delete account already there) and growing it into the full design.

**Pros**:
- Reuses a file that already exists and already works for its two current actions
- No file to delete, less code churn

**Cons**:
- `AccountScreen` was written for a narrow job (sign out, delete account); growing it to also own
  editing, navigation to a dozen placeholder rows, and the anonymous state mixes concerns a single
  file was never designed to hold
- The name `AccountScreen` no longer matches what the file does once it is the whole Profile tab

### Option 2: Build a new `ProfileScreen` from the design, retire `AccountScreen`

Write a new screen matching the Figma page, move sign out and delete account into it, and delete the
old file.

**Pros**:
- One real profile surface instead of two overlapping ones (the old file was never linked from
  navigation, so there is no live traffic to migrate carefully away from)
- The new file's shape can match the design's actual sections (header, Generals, Help and Legal)
  instead of being bent to fit an older, narrower screen

**Cons**:
- Sign out and delete account's working logic has to be carried over, not just left in place

### Option 3: Keep today's empty placeholder, defer the whole page again

Leave the Profile tab as `ComingSoonScreen` and treat this as still not the right time.

**Pros**:
- Zero work now

**Cons**:
- Does not answer the actual request (clone this page), and leaves spec 0004's open Follow up item
  (no real way to reach sign out or delete account) unresolved indefinitely

## Rationale

`AccountScreen` was never linked from navigation, so there is no live user relying on its exact
shape today, which removes the usual reason to migrate gradually (Option 2's version of the
strangler instinct: since nothing depends on the old screen yet, a direct replace carries the same
low risk as a gradual one, without the extra step). Extending it in place (Option 1) would work
today but commits the file to gaining tabs, forms, and a whole anonymous state on top of a class that
started as two buttons. Doing nothing (Option 3) does not answer the actual request or resolve spec
0004's open Follow up item.
