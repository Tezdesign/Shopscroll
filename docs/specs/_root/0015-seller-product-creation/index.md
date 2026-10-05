# 0015. Let a seller create, publish and manage products from the store area

**Date**: 2026-10-05
**Status**: In Progress

## Summary

A seller adds a product from the store area in three steps (Basics, Price and stock, Preview), with material, fit and care as an optional extra. Photos upload in the background, and the work saves itself to the server as a draft that can be reopened on any phone. A draft is a working copy kept apart from the catalog, so half finished work never shows to shoppers. One server function checks everything and publishes in a single step. Colors and sizes become real variants with their own price, stock and optional photo, and an order takes stock off the right variant at the right price. The spec also adds a Products list with quick edit of price and stock, "Create similar", and "Fill from photos" using Claude. Design source: the 11 `product-creation-*` frames in the Figma file (listed below), with the audit changes recorded as deviations.

## Requirements

**User stories**:
- As a seller, I want to list a product from my phone in a few minutes so that shoppers can buy it.
- As a seller, I want my work saved as I go so that a call, a crash or a dead battery does not lose it.
- As a seller, I want to set a price and stock for each color and size so that I do not oversell or underprice.
- As a seller, I want to see and fix my products (price, stock, drafts) without going through the whole flow again.
- As a seller with many similar items, I want to copy a product and change a few things so that I do not retype everything.
- As a shopper, I want to see only finished products, pay the price of the size and color I picked, in the right currency, and never buy a size that is sold out.

**Acceptance criteria** (the contract, each one independently checkable):
- **AC-1** (access): Only an approved seller can open the flow or the Products list. A buyer or visitor is sent to the buyer area (the existing `StoreAreaScreen` rule from spec 0014). On the server, every function, draft and photo write in this spec is refused for a non seller and for an anonymous session.
- **AC-2** (minimum to publish): A seller can publish with at least one photo, a title (2 to 100 characters), a category from the category list, a price above 0 and a whole number stock of 0 or more. The flow has three steps (Basics, Price and stock, Preview). There is no store picker: one account is one store.
- **AC-3** (details are optional): Material, fit, sleeve length and care instructions are optional and sit in a "More details" section opened from Preview. Leaving them empty never blocks publishing, and the Preview shows only what was filled in.
- **AC-4** (variants): A product with options builds one row per color and size combination. Each row has its own price (filled from the default price), stock, optional SKU and optional photo. The seller can set price or stock for all rows at once and copy a value down. Size presets (letter sizes and shoe sizes) are offered. A product has at most 100 variants. Two rows with the same color and size are refused. A product without options has exactly one variant with no color and no size.
- **AC-5** (photos): A product has 1 to 8 photos. The phone converts every photo (including HEIC from an iPhone) to JPEG with the longest side at most 1600 pixels before upload. Uploads start as soon as a photo is picked and never block typing. A failed photo shows its reason with Retry and Remove, and the other photos and fields are kept. The seller can pick the cover, reorder photos, and link a color to one of the photos. Photos are stored under the seller's own folder, and a photo or variant image that points anywhere else is refused at publish.
- **AC-6** (drafts): A draft is a row in `product_drafts` created when the first photo is added or the first field is typed. It saves again within 2 seconds after the seller stops typing, and stores the current step. Closing the app and coming back, even on another phone, resumes the draft at that step. A draft never appears in the catalog and no other seller can read it. "Save draft" leaves the flow and shows a short confirmation.
- **AC-7** (publish check): `save_product` checks every rule (photo count and paths, title, category, 1 to 100 variants, no duplicate color and size, each variant price above 0, stock 0 or more) and writes the product and all its variants in one transaction, or changes nothing. A refusal carries a reason code and the variant it concerns, the app shows it next to the field with a link to fix it, and the draft is kept untouched. Calling it again after it worked returns the same product and changes nothing.
- **AC-8** (publish): The seller can tap Publish while photos are still uploading. The button shows "Waiting for photos (2 of 3)" and publishes when they finish, as long as the app stays open. If the seller leaves first, nothing is published: the draft stays in the Drafts list marked "Not published yet". When publishing succeeds the product is live and shows in the buyer app.
- **AC-9** (money): Prices are stored exactly to 3 decimals. The currency belongs to the store (today every store is `TND`, the default) and is written on the product when it is first saved. The seed products are relabeled `TND`. The flow shows "89.000 TND", uses a number keyboard, and refuses a price with more than 3 decimals. The buyer product card and product page show the price in the product's own currency.
- **AC-10** (stock at order time): `place_order` finds the variant for each cart line (by product, color and size). A line that matches no variant, or a product that is not `live`, is refused as `product_unavailable`. It adds up the quantities per variant, refuses the order with `out_of_stock` if any variant has less stock than asked, and takes the stock off in the same transaction. Two orders for the last unit at the same time: exactly one succeeds and the other gets `out_of_stock`, never a raw database error.
- **AC-11** (Products list): A seller sees their own products in four tabs: Live, Drafts, Out of stock (live products with no stock) and Archived, 20 per page, each row showing cover, title, price range and total stock. Tapping a row opens it for editing. A quick edit sheet changes a variant's price and stock in one small call without opening the flow. A live product can be archived and restored. A draft or an archived product can be deleted, and its photos are removed from storage; a live product cannot be deleted (archive it first).
- **AC-12** (editing live products): Editing a live product opens a working copy as a draft linked to that product. Saving it goes through the same `save_product` checks and replaces the product and its variants in one step, so a live product can never be half edited or invalid. A price change affects only future orders (past receipts keep the price they were bought at).
- **AC-13** (Fill from photos): With at least one uploaded photo, "Fill from photos" asks the `autofill-product` Edge Function for suggestions: title, description, category (from the list), color names and material. Suggestions show as editable values and nothing is saved until the seller accepts them. A failure or a wait over 20 seconds leaves the form untouched with a short message. Each seller can run it 30 times a day (counted on the Tunis calendar day); every run that starts counts, even a failed one, and the 31st returns `quota_exceeded` with the remaining count shown. Only a seller can call it, and it reads photos only from the caller's own draft or product.
- **AC-14** (Create similar): "Create similar" makes a new draft that copies the title, description, category, details and variants (colors, sizes, prices) of an existing product. Stock is set to 0 and photos are not copied. The original does not change.
- **AC-15** (finish screens): After Publish the seller sees a Live screen with "View product" and "Add another". There is no "Create a reel" button in v1 because sellers cannot create reels yet. There is no separate Draft saved screen (AC-6 covers it).
- **AC-16** (security): A seller cannot read, change or delete another seller's draft, product, variant or photo. Shoppers (including signed out visitors) can read only `live` products and their variants. No client can insert or update a row in `products` or `product_variants` directly: they change only through `save_product`, `set_product_archived`, `update_variant_quick` and `place_order`. Delete is allowed on a client's own `archived` product only. A seller can write, replace and delete photos only under their own folder in the `product-images` bucket.
- **AC-17** (design and accessibility): The new screens use the design tokens (no literal `Color(0x...)` or raw sizes), keep helper text at 12 pixels or more, make every tap target at least 44 pixels, and name the Figma node each screen reproduces.
- **AC-18** (no backend): Without Supabase configuration the whole flow, the list and quick edit work against an in memory mock repository (as the other features do), and "Fill from photos" returns one fixed sample suggestion.
- **AC-19** (the buyer pays the variant price): The buyer product page shows the price and stock of the color and size picked. The cart line, the order total and the receipt use that variant's price. `place_order` takes the unit price from the variant, the app sends the expected subtotal with 3 decimals, and an order of 3 decimal prices does not fail with `price_changed`. A cart with products of different currencies is refused with `mixed_currency`. Cart and Saved screens skip a product that is no longer visible (archived) instead of crashing.

## Decision

**Chosen option**: Option 2: a three step flow, drafts as working copies, and one atomic save function

Build the flow around a new `product_variants` table and a `status` on `products` (live or archived). Drafts live in their own table, `product_drafts`, as a JSON working copy that the app saves as the seller types. Only the server function `save_product` writes `products` and `product_variants`, after checking every rule, in one transaction. The same function handles a new product and an edit of a live one.

**Implementation skills**: `supabase` (`supabase/agent-skills`, `.agents/skills/supabase/`) · `supabase-postgres-best-practices` (`supabase/agent-skills`, `.agents/skills/supabase-postgres-best-practices/`) · `claude-api` (the Claude API skill, for the `autofill-product` function)

**Design source**: the Figma file `toOakybJ0DaJmU7vcEC0AW`, page "The design - seller" (`3001:8811`). Frames:

| Frame | Node |
|---|---|
| product-creation-basics-empty | `5523:28160` |
| product-creation-basics-filled | `5523:27381` |
| product-creation-basics-upload-error | `5523:28361` |
| product-creation-inventory-simple | `5523:28572` |
| product-creation-inventory-variants | `5523:27585` |
| product-creation-details-default | `5523:27763` |
| product-creation-preview-ready | `5523:27981` |
| product-creation-preview-validation-error | `5523:28746` |
| product-creation-draft-saved | `5523:28966` |
| product-creation-publishing-loading | `5523:29050` |
| product-creation-publish-success | `5523:29114` |

**Deviations from the frames** (each one is a change from the audit and must be written in the screen's doc comment):
- The Store dropdown is removed (one account is one store).
- Four steps become three. Step 3 "Details" moves into an optional "More details" section reached from Preview. The Delivery, payment and returns block and the "Authentic product" line are removed from the flow and the preview.
- Disabled Continue and Publish buttons are replaced by enabled buttons that show what is missing when tapped.
- The full screen "Draft saved" and "Publishing" screens become a toast and an inline progress state.
- The "Create a reel for this product" card on the success screen is left out until a seller can create reels.
- Colors link to photos (new), a "Fill from photos" button sits above the title (new), and the Preview price error is fixable on the spot, not only by going back to step 2.
- The Returns row icon in the preview is a back arrow in the frame; when policies return, use a returns icon.

## Rationale

Reasoning and options: see [rationale.md](rationale.md).

## Feature design

**Data model sketch**:

| Table | Change | Fields |
|---|---|---|
| `user_profiles` | add column | `currency text not null default 'TND'`, check `^[A-Z]{3}$`. Not in any client column grant (migration `0005` grants only listed columns). |
| `products` | add columns, tighten | `status text not null default 'live'` check in (`live`, `archived`); `currency text not null default 'TND'`; `attributes jsonb not null default '{}'`; `updated_at timestamptz not null default now()`. `price` and `original_price` widen to `numeric(12,3)`. `price` holds the lowest variant price (written by `save_product` and `update_variant_quick`). Existing rows stay `live` and become `TND`. |
| `product_variants` | new | `id uuid pk`, `product_id uuid not null` (fk `products`, cascade), `color_name text`, `color_value bigint` (ARGB, same form as `color_options`), `size text`, `price numeric(12,3) not null` (above 0), `stock integer not null default 0` (0 or more), `sku text` (64 characters at most), `image_path text` (one of the product's photos), `position integer not null default 0`. Unique per product on (`coalesce(color_value, -1)`, `coalesce(size, '')`). A migration step creates one variant for every existing product (one per color and size, or one plain variant), with the product's price and stock 10 (or 0 when `in_stock` is false), so every live product has variants. |
| `product_drafts` | new | `id uuid pk` (made by the app, and it becomes the product id when published), `store_id text not null` (fk `user_profiles`, cascade), `source_product_id uuid` (set when editing a live product), `step integer not null default 1` (1 to 3), `payload jsonb not null default '{}'` (under 200 KB), `updated_at timestamptz not null default now()`. The payload holds title, description, category, attributes, photo paths in order, cover, options and the variant rows. Owner only, seller only. |
| `product_categories` | new | `slug text pk`, `label text not null`, `position integer not null`. Publicly readable. Seeded from the categories the buyer app already filters by. The single source for the app and for `save_product`. |
| `ai_autofill_usage` | new | `user_id text`, `day date`, `runs integer not null default 0`, primary key (`user_id`, `day`). Row level security on, no client policy. |
| `orders`, `order_items` | widen money | `orders.total_amount`, `subtotal`, `delivery_fee` and `order_items.unit_price` become `numeric(12,3)`. `cart_items` keeps `selected_size` and `selected_color`; the variant is found from these. |
| Storage | new bucket | `product-images`: public read, JPEG only, 2 MB limit. A seller (not anonymous) may insert, replace and delete only under `<their clerk sub>/<draft or product id>/`. |

`products.color_options`, `sizes` and `image_urls` stay as the buyer app reads them, and `save_product` fills them from the draft. `image_url` is the cover. `products.in_stock` is kept in step with variant stock by a small trigger on `product_variants` (`sync_product_in_stock`, `security definer`, the same pattern as `sync_reel_like_count`), because `place_order` and the quick edit change stock outside `save_product`.

**State transitions**:
- Draft (a row in `product_drafts`) → `live` product, by `save_product`; the draft row is deleted on success.
- Live product → draft copy (a new `product_drafts` row with `source_product_id`) when the seller edits; `save_product` writes it back and deletes the copy.
- `live` ↔ `archived`, only by `set_product_archived`.
- Delete: a draft any time; a product only when `archived`. A live product cannot be deleted.

**API surface**:

| Endpoint | Method | Key inputs | Key outputs | Auth | Key errors |
|---|---|---|---|---|---|
| `product_drafts` (table) | insert, update, delete, select | `id`, `step`, `payload`, `source_product_id` | row | seller, own rows | RLS refusal, payload too large |
| `save_product(p_draft_id)` | RPC | `p_draft_id uuid` | product id | seller, own draft | `no_session`, `not_seller`, `not_found`, `no_photo`, `bad_photo_path`, `bad_title`, `bad_category`, `no_variants`, `too_many_variants`, `duplicate_variant`, `missing_price:<variant id>`, `bad_stock:<variant id>` |
| `set_product_archived(p_id, p_archived)` | RPC | `p_id uuid`, `p_archived boolean` | product id | seller, own product | `not_found` |
| `update_variant_quick(p_variant_id, p_price, p_stock)` | RPC | variant id, price above 0, stock 0 or more | variant id | seller, own product | `not_found`, `missing_price`, `bad_stock` |
| `products` (table) | select, delete | filters on `status`, `in_stock`, `store_id` | rows | read: live for all, own for the seller; delete: own `archived` only | RLS refusal |
| `place_order(...)` (changed) | RPC | as today, expected subtotal with 3 decimals | order id | signed in | adds `out_of_stock:<product id>`, `mixed_currency` |
| `autofill-product` | POST (Edge Function) | `draft_id uuid` or `product_id uuid` | `title`, `description`, `category`, `colors[]`, `material`, `remaining` | seller (Clerk token) | 401 no session, 403 `not_seller`, 404 `not_found`, 422 `no_photos`, 429 `quota_exceeded`, 504 `timeout` |
| Storage `product-images` | upload, replace, delete | JPEG, 2 MB at most | public URL | seller, own folder | refused outside own folder |

"Create similar" needs no server call: the app builds a new draft payload from the product's rows (stock 0, no photos). The Products list is a normal select on `products` with `product_variants(stock, price)` embedded, filtered by `store_id` and `status`, sorted by `updated_at` descending, 20 per page. Out of stock is `status = 'live'` and `in_stock = false`. Drafts come from `product_drafts`, newest first.

**Key invariants**:
- A `live` product has a title, a category from `product_categories`, at least one photo path under its own folder, 1 to 100 variants, and every variant has a price above 0 and a stock of 0 or more. Only `save_product` creates or changes these rows, and it locks the product row for the whole write, so two saves cannot both pass a count check.
- A shopper can read only `live` products and the variants of live products. A seller can also read their own archived products.
- `place_order` refuses any product that is not `live`, even if a cart row still points at it.
- `products.in_stock` always matches the variants; `products.price` is the lowest variant price.
- Stock never goes below 0. The order takes stock off per variant with `update ... set stock = stock - q where stock >= q` and checks the number of rows changed.
- `currency` on a product never changes after it is first saved. Changing a store's currency is not supported in v1.
- An order line keeps its own price, title and picture (already true), so editing or archiving a product never changes a receipt.

**Security model**:
- Roles come from spec 0012. Every function checks `is_seller()`, a non anonymous session, and `store_id = auth.jwt() ->> 'sub'`. All the new functions are `security definer`, set `search_path = ''`, and are granted to `authenticated` only, as in `supabase/AGENTS.md` (`take_autofill_run` to `service_role` only).
- The migration must `revoke insert, update on products from authenticated` and grant back nothing, which also removes the old column grants from migration `0004`, then keep `delete` under a policy that requires `status = 'archived'`. The old grants would otherwise let a client write `store_name`, `in_stock` and the rest. `product_variants` gets no client write grant at all.
- The "products are publicly readable" policy becomes `status = 'live' or store_id = auth.jwt() ->> 'sub'`. `product_variants` follows its parent.
- `save_product` accepts photo paths, never URLs, and refuses any path that does not start with `<their sub>/<the draft id>/`. A variant `image_path` must be one of the product's photos. `autofill-product` downloads photos by storage path from the caller's own draft or product, sends at most 4, and checks the answer against a fixed JSON shape (category must exist in the list, lengths capped), because text printed on a photo could try to steer the model. The result is only a suggestion shown to the seller.
- No regulated data. Photos are public by design once the product is live. Draft photos also sit in a public bucket under hard to guess paths; this is accepted for v1 and listed in Follow up.

**Configuration required**:
- `ANTHROPIC_API_KEY`: the Claude API key for `autofill-product` (a Supabase secret, set with `supabase secrets set`, never in the repo).
- `AUTOFILL_MODEL`: defaults to `claude-sonnet-5-5`.
- `AUTOFILL_DAILY_LIMIT`: defaults to `30`.
- `CLERK_ISSUER`: already used by other functions; deploy `autofill-product` with `--no-verify-jwt` like them.
- Prerequisite: an Anthropic account with billing, before the function can be tried.

**Critical test scenarios**:
- Happy path: add two photos, a title, a category, a price and stock, publish; the product appears in the buyer app with the right price and currency, verifies **AC-2**, **AC-8**, **AC-9**.
- Happy path: 2 colors by 3 sizes makes 6 rows with different prices; the buyer picks Black and L, sees that price, orders; the receipt shows that price and that variant's stock goes down by one, verifies **AC-4**, **AC-10**, **AC-19**.
- Happy path: edit a live product's title and add a size in one save; no step in between is refused, and shoppers never see a half edited product, verifies **AC-12**.
- Failure: one variant has no price; `save_product` is refused with `missing_price:<id>`, the draft is unchanged, nothing reaches the catalog, verifies **AC-7**.
- Failure: a photo upload drops halfway; the other photos and fields stay, Retry works, verifies **AC-5**.
- Failure: two buyers order the last unit at the same time, and one cart holds the same variant on two lines; one order succeeds, the others get `out_of_stock`, verifies **AC-10**.
- Failure: a cart line points at an archived product, or at a size that no longer exists; the order is refused as `product_unavailable`, and the cart screen does not crash, verifies **AC-10**, **AC-19**.
- Failure: a 3 decimal price order (89.125 TND) goes through without `price_changed`; a cart with a TND and a USD product is refused with `mixed_currency`, verifies **AC-19**.
- Failure: `autofill-product` times out; the form is unchanged and the run still counts, verifies **AC-13**.
- Permission: a second seller tries to read, update, save or delete the first seller's draft, product or photo path, or saves a draft whose photo path points to another folder; all refused. A buyer or an anonymous session calls `save_product`; refused, verifies **AC-1**, **AC-5**, **AC-16**.
- Permission: a signed out visitor lists products; sees no archived products and no drafts. A seller tries to delete a live product directly; refused, verifies **AC-11**, **AC-16**.
- Idempotency: `save_product` called twice for the same draft changes nothing the second time, verifies **AC-7**.

## Build plan

Build approach: none recorded in `AGENTS.md` ("<TBD, set by /scope>"), so this follows end to end slices (Tracer Bullet): first one thin path from the database to the screen, then the pieces thicken. Assumption stated; change it if the project picks another approach.

1. [ ] Migration `0008_seller_products.sql`: `user_profiles.currency`; `products` columns, widened prices, `TND` backfill; `product_variants` with the backfill for existing products; `product_categories` (seeded); `product_drafts` with its policies; the `sync_product_in_stock` trigger; the new read policy; the revoke of old client grants; `save_product`, `set_product_archived`, `update_variant_quick`; the `product-images` bucket and its policies. Add `supabase/checks/seller_products.sql` (permission, status and invariant checks, each rolling back), satisfies **AC-2**, **AC-4**, **AC-6**, **AC-7**, **AC-11**, **AC-12**, **AC-16**
   Status: Written, and its SQL checks pass on a local Postgres with Supabase stand ins (all older check files pass too). Not yet applied to a Supabase project.
2. [x] Shared model and repositories: `ProductVariant`, `ProductStatus`, `ProductDraft`, `Money` (exact decimal and currency formatting) in `packages/shared`; extend `Product`; a `SellerProductRepository` with a Supabase version and an in memory mock version, behind Riverpod providers in `apps/buyer/lib/data/`. Buyer side: price labels use the product's currency, the product page reads the variants and shows the picked color and size's price and stock, and the cart and Saved repositories skip a product that comes back empty, satisfies **AC-9**, **AC-18**, **AC-19**
3. [x] Thin slice, end to end: the Products screen (empty list), the flow for a product without options (Basics, Price and stock, Preview, Publish through `save_product`), photos picked, converted and uploaded, and the Live screen. Entry from the store area placeholder (two buttons, Products and Add product) until the seller shell spec exists. Routes `/store/products`, `/store/products/new`, `/store/products/:id/edit`, declared before `/store/:id`, satisfies **AC-1**, **AC-2**, **AC-5**, **AC-8**, **AC-15**, **AC-17**
4. [x] Photos made robust: background queue with per photo state, Retry and Remove (with storage delete), cover choice, reorder, HEIC conversion, the upload error state from the design, satisfies **AC-5**
5. [x] Variants: options toggle, color and size editors with presets, the generated table, set all and copy down, SKU and color to photo link, satisfies **AC-4**
6. [x] Draft autosave: debounced saves of the payload and step, resume at the saved step, inline missing item messages, enabled buttons that explain what is missing, the waiting for photos state, satisfies **AC-6**, **AC-7**, **AC-8**
7. [x] "More details" section with the clothing attribute set (material, fit, sleeve length, care) and free key and value rows for other categories, shown in Preview, satisfies **AC-3**
8. [x] Products list finish: the four tabs, pagination, quick edit sheet, archive and restore, delete with photo clean up, edit a live product as a draft copy, satisfies **AC-11**, **AC-12**
9. [ ] Migration `0009_place_order_variants.sql`: `orders` and `order_items` money columns to `numeric(12,3)`; `place_order` finds the variant per line, refuses draft, archived and unmatched lines, adds up per variant, takes the unit price from the variant, refuses `mixed_currency`, and takes stock off with the guarded update. In the app: send the expected subtotal with 3 decimals (`supabase_order_repository.dart`) and map `out_of_stock` and `mixed_currency` in the cart and checkout screens. Extend the checks with a two session race and a same variant on two lines test, satisfies **AC-10**, **AC-19**
   Status: Written and checked on a local Postgres, including a real two session race for the last unit. Not yet applied to a Supabase project.
10. [ ] Migration `0010_autofill.sql` (`ai_autofill_usage`, `take_autofill_run` for `service_role` only, counting every started run) and the `autofill-product` Edge Function (logic in `_shared/autofill_product.ts` with Deno tests for the answer check and the daily limit). Add "Create similar" to the list (builds a draft payload in the app) and "Fill from photos" to Basics, satisfies **AC-13**, **AC-14**
   Status: The function logic and its 18 tests pass on Node. The function was not run on Deno and not deployed, and the migration is not yet applied to a Supabase project.
11. [ ] Tests and checks: widget tests for each screen (wrap in `MaterialApp(theme: AppTheme.light, ...)`, pump past `mockNetworkDelay`), repository tests for both backends, `deno test supabase/functions/_shared/`, then run the SQL checks on a test database, satisfies **AC-1** to **AC-19**
   Status: Tests are written and pass (shared 143, buyer 461, functions 40). Still to do: run the SQL checks on a real Supabase test project, and a first run with real Clerk and Supabase values.

## Consequences

**Positive**:
- Sellers can publish a simple product in one short pass and a clothing item with variants without leaving the flow.
- Drafts survive crashes and phone changes, and never touch the catalog, so there are no half finished rows for shoppers or for the checks to trip over.
- One server function owns what "live" means and writes everything in one transaction, for a new product, an edit, and any later CSV or API import.
- Stock is enforced and each variant sells at its own price, so the Home "Out of stock" card in the seller design has real data behind it.
- Clients lose all direct write access to `products` and `product_variants`, which is a smaller attack surface than the column grants it replaces.

**Negative / tradeoffs**:
- More schema and more code: two new tables of data, two small ones, a trigger, and three functions. The spec also reaches into the buyer app (product page, cart, Saved, checkout) and into the live `place_order` function, so it needs careful rollout and its own checks.
- Drafts autosave to the server, so every pause while typing is a write, and unfinished drafts exist for sellers who never come back (a clean up job is a Follow up item). A draft is a JSON blob, so its fields are only checked when saved, not as the seller types.
- Publishing waits for photos on the phone. If the seller leaves first, nothing is published and they must come back to the draft.
- `Fill from photos` costs money on every run and depends on the Claude API. The daily limit caps the cost, but it is a running expense and a new secret to look after.
- Currency is a store field, but delivery fees at checkout are still placeholders in dollars. A cart with two currencies is refused, not converted.
- `products.price` now means "lowest variant price", so the buyer card shows a "from" price when variants differ.

**Neutral**:
- Existing seeded products get generated variants and the `TND` label, so they behave like any new product.
- The store area still shows a placeholder with two entry buttons until the seller shell spec exists.

## Follow-up

- [ ] Seller shell spec: the seller header, tab bar, Home, Activity and Profile. This spec's routes and entry buttons move there.
- [ ] Add this feature to `docs/scope/_root/scope.md` (no scope row exists yet), for example "Seller product creation".
- [ ] Restock when an order is canceled. There is no cancel path in the app yet, so v1 does not restock.
- [ ] Delivery fees and placeholder prices at checkout are in dollars; set the real TND fees.
- [ ] Draft photos sit in a public bucket under hard to guess paths. Decide later whether drafts need a private bucket and signed links.
- [ ] A clean up job for drafts and their photos untouched for 30 days, and for photos left behind when a delete could not reach storage (same style as the visitor application job).
- [ ] Buyer product page: switch the gallery to a color's photo when that color is picked (needs the variant `image_path` on the read side).
- [ ] Later specs: import from a product link; bulk CSV (rows per variant, grouped by a handle) and a store API key for brands with many items; create a product from a reel; product video; per product policy exceptions once store settings exist; seller reel creation (then the success screen can offer a reel).
- [ ] Seller order handling (mark shipped, cancel) lives with the Activity design, not here.
- [ ] Categories in the buyer Discover and Home screens are still written in code. Read them from `product_categories` there too.
- [ ] If the work runs long, move tasks 9 and 10 into their own specs (see the premise note in `rationale.md`).
- [ ] Add the new nested context file `apps/buyer/lib/features/seller_products/AGENTS.md` after the build (via /sync).
