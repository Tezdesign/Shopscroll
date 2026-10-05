# 0015 rationale: seller product creation

The build spec is [index.md](index.md). This file holds the reasoning and the evidence behind it.

## Context

> ⚠️ Premise note: This spec holds four pieces that could each ship alone: the creation flow, real variants with stock at order time, the Products list, and the two helpers (Fill from photos, Create similar). Kept together, a slip in the AI function or in the `place_order` change could hold back the core flow. The build plan is ordered so the core flow (tasks 1 to 8) is usable before the stock change (task 9) and the helpers (task 10). Task 2 and task 9 also change the buyer app (product page, cart, Saved, checkout), so this is not only seller work. If the work runs long, cut after task 8 and move 9 and 10 into their own specs. Also, this feature assumes a seller shell (header, tab bar, Home, Activity, Profile) that has no spec yet. The spec uses two temporary entry buttons in the store area until that shell exists.

Shopscroll has a store area that only approved sellers can enter (spec 0014), and sellers are already allowed to write their own rows in `products` (spec 0012). But nothing lets a seller actually list something. The store area shows a "Your store" placeholder, and the app has no product form, no photo upload, and no way to see or fix products after they are made.

The data underneath is thin for selling real goods. A `Product` has one price, a list of color swatches, a list of sizes and a single `inStock` flag. It cannot say that Black in size L costs more, that only 2 are left, or that it is a draft nobody can see yet. Orders do not take stock off anything, so the same last item can be sold twice. Prices are `numeric(10,2)`, but the Tunisian dinar has 3 decimals (the design shows "89.000 TND"), and the buyer app prints "$".

The design is a set of 11 phone frames in Figma. It is a good start, with draft saving, a shopper preview and clear error states. An audit of the frames found these problems, which this spec fixes:
- Colors are not linked to photos, so a shopper who taps Black can still see the burgundy dress.
- Four steps is long when only five things are needed to publish, and the Details step is optional in practice.
- A Store dropdown exists, but one account is one store.
- Disabled buttons do not say why. A price error on the last step cannot be fixed there.
- "Keep this screen open" while publishing, and a full screen "Draft saved", interrupt the seller.
- "Authentic product from Bershka" is a claim the app has not checked. Delivery, payment and returns "store defaults" refer to a store settings feature that does not exist.
- The variant table has no bulk edit or presets, so 40 rows would be unusable.
- Photos accept only JPG and PNG, but iPhones take HEIC.
- No Products list exists, so drafts, edits and the Home "Out of stock" card have nowhere to point.

If nothing is decided, sellers cannot list at all, and any quick patch (a stock number on the product) would be rebuilt as soon as variants are needed.

## Options considered

### Option 1: Build the frames as drawn on the current schema

Keep four steps and the Store dropdown, store color and size as the existing arrays, and add one stock number and a draft flag to `products`.

**Pros**:
- Fastest to a first screen. No change to the buyer app or to orders.
- Matches the frames exactly.

**Cons**:
- Cannot hold a price or stock per variant, which is what the second frame promises. The table in the design would have nowhere to save.
- Overselling stays possible.
- Every audit problem above ships as designed, and variants have to be bolted on later, which means rebuilding the form and migrating data.

### Option 2: Three step flow, drafts as working copies, one atomic save function

Add `product_variants`, a `status` on products (live or archived), and a separate `product_drafts` table holding the half finished work as JSON. One function, `save_product`, checks every rule and writes the product and its variants in one transaction, for new products and for edits. Fix the audit problems in the flow. Add the Products list. Make `place_order` use variant price and stock. Add Fill from photos and Create similar as the last tasks.

**Pros**:
- The data matches how clothing and most goods are actually sold, and matches the way Shopify and others store it, so a CSV or API import later is a thin layer.
- One place decides what "live" means, for the app now and for any import later.
- Half finished work never touches the catalog, so no trigger has to tolerate empty titles, and editing a live product cannot be caught half done.
- Clients lose direct write access to `products` and `product_variants`.
- Fixes overselling and gives the seller screens real stock to show.

**Cons**:
- Large change: three migrations, a trigger, a change to the purchase function, a new Edge Function, and changes to the buyer product page, cart, Saved and checkout.
- A draft is a JSON blob, so its fields are checked only when saved.
- Needs careful rollout because `place_order` is already live.

### Option 2b: Same, but drafts as `draft` rows inside `products`

The first version of this spec. `products` gets a `draft` status, drafts are real rows with empty titles allowed, and the app writes them field by field with column grants.

**Pros**:
- Fields are typed columns from the first save. No JSON to unpack.
- Fewer tables.

**Cons**:
- Needs a status aware read policy, column grants that must also remove the old ones, and a check on every save that has to let incomplete drafts through but stop live products from being edited into an invalid state. Those two goals fight each other, and editing a live product field by field cannot be made safe.
- Empty draft rows sit next to real products in a table every shopper query touches.
- The cross check (below) found this was the source of most problems in the first version.

### Option 3: One scrolling page with sticky Publish

Put all sections (photos, basics, variants, details) on one long screen, like Vinted.

**Pros**:
- Quickest for a single simple item. No steps, no "Continue".
- Everything visible at once.

**Cons**:
- Gets long and heavy with a variants table and a preview on a phone.
- The preview and the error summary have no natural place, and the flow loses the clear progress the design already shows.

### Option 4: Import first, a minimal form second

Make bulk CSV and an API key the main way to create products (like Amazon or large Shopify stores) and keep the phone form to the bare minimum.

**Pros**:
- Best for brands with hundreds of items.
- Pushes data quality to the seller's own systems.

**Cons**:
- A CSV is awkward on a phone, and most Shopscroll sellers will start small, listing from a phone.
- It still needs the variants table and the publish rules, so it is not a shortcut. It also adds an API surface, keys and rate limits before the basic flow works.

## Rationale

Option 2 is chosen because the forces in Context all point at the data, not at the screens. Sellers of clothing need per variant price and stock, the design already shows that table, and the cost of adding it later is a rebuilt form and a data migration. Doing it once now, behind a trigger that keeps the old buyer columns in step, means the buyer app can keep reading products the way it does today.

Option 1 was rejected even though it is faster: it ships a table with nowhere to save, and leaves overselling in place. Option 3 is good for single items but works against the variants table and the preview. Option 4 is the right direction for large sellers, but it needs everything Option 2 builds, so Option 2 is its first half. The spec keeps the data in the shape a Shopify style import wants, and lists import and API as later work.

Drafts were first planned as rows in `products` (Option 2b). A cross check by a second model showed that this fights itself: the same table and the same checks have to allow an empty draft and forbid an invalid live product, and autosave plus a field by field live edit can never pass both. Keeping drafts as a working copy in their own table, and publishing with one atomic function, removes that conflict, gives the saved step a place to live, and leaves the catalog table free of unfinished rows. The engineer asked for server side autosave, and this still is.

Choices made without a pick from the engineer are recorded here. Money is stored as an exact `numeric(12,3)` (runner up: whole minor units such as millimes in an integer, which is stricter but would rewrite cart and order code now). "Create similar" copies data but not photos (runner up: copy the photo files too, which is nicer but needs file copying and clean up). The seed products are relabeled `TND` and given generated variants (runner up: keep them as dollars and refuse mixed carts, which leaves the demo data in a second currency for no gain). Fill from photos uses `claude-sonnet-5-5` because the engineer chose it over the cheaper Haiku, accepting a higher cost per run for better detail on fabric and fit, with the daily limit as the cost cap; every started run counts, so a seller cannot run up cost by timing out on purpose.

The three step shape follows what the fastest listing apps do: photos first, only a handful of required fields, everything else optional. The seller keeps the preview, which is the best part of the design.

## Evidence: how other platforms handle product creation

Gathered from web searches on 2026-10-05, then summarised here (no links, as chosen). Items marked "memory" are from general knowledge and were not checked that day.

- **Depop and Vinted** are photo first. One photo fills category, color, brand, size and description with AI, and the seller edits instead of typing. This is why Fill from photos is in v1.
- **Etsy's API** creates a draft listing first and publishes later. Required fields are title, description, price, quantity, category, images and a shipping profile. This matches draft first here.
- **TikTok Shop** offers six ways to add products: one at a time, bulk upload from a category Excel template (50 per batch), keyword match, link import, the app and an API. It can also build a product video from more than four images. It is the closest competitor to a shopping plus video app, and is the reason the later specs list link import and bulk upload.
- **Shopify** uses one row per variant in a CSV, grouped by a handle, with the first row holding the title and the main image (up to 250 images). Its GraphQL API can create variants in bulk. This is the model for `product_variants` and for a later CSV import.
- **Amazon** uses a category template file or the Selling Partner API, and lets a seller attach to an existing catalog entry before creating a new one. This matters for brands with many items, less for Shopscroll today.
- eBay (memory): identifies items from a photo or barcode and offers an inventory API keyed by SKU. Shopify (memory): has built in AI that drafts descriptions.

## Evidence: what the code showed

- `products` has no variants, no draft status, no stock count, no currency, and `price numeric(10,2)` (`supabase/schema.sql`).
- `cart_items` and `order_items` hold `selected_size` and `selected_color`, not a variant id. So `place_order` can find the variant from product, color and size without changing the cart tables.
- `place_order` already prices from the products table, runs in one transaction, is safe to repeat, and raises named errors the app reads. Adding `out_of_stock` follows the same pattern.
- Sellers can already insert, update and delete their own products (migration `0004`), with column grants. This spec narrows those grants so a client cannot set `status` or `currency`.
- `place_order` prices each line from `products.price` and checks `in_stock`, not status, so without a change a variant price would be ignored or rejected, and a draft or archived product could be ordered. The order screen sends the expected subtotal with 2 decimals (`supabase_order_repository.dart`), which fails for 3 decimal prices. The cart and Saved repositories cast the embedded product to a map, so an archived product that the new read policy hides would crash them.
- A cross check by a second model (Opus) on 2026-10-05 raised these and about fifteen more points: the variant price gap, seed products with no variants, old column grants surviving, a live delete not blocked, photo URLs the caller could control, quota counting, storage policies, and a variant count race. All were folded into the spec; the draft redesign above came from the same review.
- `store_id` is the seller's profile id, so one account is one store. The Store dropdown in the frames has no data behind it.
- `sync_reel_like_count` is the existing example of a trigger that keeps a stored count in step; the variant trigger follows it.
- Routes: `/store/:id` shows a store page. The new `/store/products` routes must be declared before it. Store ids are Clerk ids or UUIDs, so a real store cannot be called `products`.
