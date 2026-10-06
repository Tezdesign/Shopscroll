# admin-review

The static page the admin's email links to (spec 0016): it shows one seller application and its ID photos
and approves or rejects it. No build step, no dependencies.

- `index.html`, `app.js`, `style.css`: the page. It reads `#t=<token>` from the link, removes it from the
  address bar, and talks only to the `review-application` Edge Function.
- `config.js`: the function's address. Change it if the Supabase project changes.
- `_headers`: Cloudflare Pages response headers (content security policy, no framing, no referrer). It names the
  project's Supabase address, so change it together with `config.js`.

Deploy: a Cloudflare Pages project with no build command and the output directory `web/admin-review`. Then set
that address as the `REVIEW_PAGE_URL` function secret (the exact origin matters for CORS, a preview address is
refused).
