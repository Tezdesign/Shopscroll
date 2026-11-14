# 0020 rationale: seller chat

## Context

Spec 0011 built the chat server for both roles: every function takes the role it acts in, and the store role is already covered by SQL checks. It built screens for the buyer only and left the seller's to this spec, because the Figma file had no seller chat frames. The seller shell (spec 0019) now has a Messages tab that shows a Coming soon page.

## Options

1. **Reuse the buyer's thread code with a role.** (chosen) One thread screen, one composer, one set of bubbles, one set of rules. The seller gets a new inbox screen and an entry from the order.
2. **A separate seller chat feature.** Its own thread screen and logic. Free to diverge, but two copies of the send, merge, seen and delete rules to keep in step, and every future chat change (photos, product cards) done twice.
3. **Show the seller an inbox only, no thread.** A list with a "reply in the app" message. Does not solve the job.
4. **Build seller chat into the order detail only.** One thread per order. Customers write to a store, not to an order, and one customer can have many orders, so it would split one conversation into several.

## Decision

Option 1. The server already treats the two roles as one conversation seen from two sides, so the app should too. The only real differences are the list (the other side is a customer) and the entry point (a store may only start from an order), and both are small.

## Choices made without asking

- **"Message customer" on the order detail.** The server only lets a store start a thread by naming an order (spec 0011 AC-14), so the order is the natural entry. It is also where a seller already looks at the customer.
- **No link on the customer's name.** A customer has no public page.
- **Dot on the header chat icons.** The Home and Activity headers already draw a chat icon that does nothing (spec 0018). This gives it its job.
- **No templates, no auto reply, no broadcast.** Each would need its own spec and rules against spam.
