# DentaFlex — Dental equipment representative website

A Next.js + Supabase application with a premium public catalogue, English/French/Arabic UI (including RTL), product quote form that prepares a WhatsApp message, and a protected admin dashboard.

## Included

- Public home page, representative profile, searchable/filterable catalogue, contact links and downloadable PDF catalogue.
- Quote modal preselects the product and creates a language-specific WhatsApp click-to-chat draft. The visitor reviews and sends it manually.
- `/admin` login using Supabase Auth; no public registration UI.
- Admin areas for profile, brand, products, categories, contact/social details, section copy, catalog PDF, translations and SEO.
- Product create/edit/duplicate/publish/hide/reorder/delete; multilingual name and descriptions, SKU, category, price/quote-only, image, gallery and optional PDF.
- Supabase PostgreSQL schema, RLS policies, public media bucket and hidden-by-default sample products.
- Responsive design, focus styles, semantic controls and basic metadata.

## Requirements

- Node.js 18.17+ (Node 20 LTS recommended)
- Supabase project
- Vercel account (optional for deployment)

## Local setup

1. Create a project at https://supabase.com/dashboard.
2. In Supabase, open **SQL Editor**, paste all of `supabase/schema.sql`, and run it.
3. Open **Project Settings → API** and copy the Project URL and publishable/anon key.
4. Copy `.env.example` to `.env.local` and set:
   ```env
   NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
   ```
   Do not add the service-role key to the frontend or to a `NEXT_PUBLIC_` variable.
5. In Supabase **Authentication → Providers / Sign In**, enable Email and Password. Under **Auth → Settings**, disable public sign-ups.
6. Create the first administrator: use **Authentication → Users → Add user** to create the owner's account. Confirm the user if your settings require it. Copy the user's UUID, then run this in SQL Editor:
   ```sql
   insert into public.admin_users(user_id) values ('PASTE_AUTH_USER_UUID_HERE');
   ```
   This is the authorization allow-list. Creating a regular Auth user alone does not grant dashboard access.
7. Install and run:
   ```bash
   npm install
   npm run dev
   ```
8. Open `http://localhost:3000` and `http://localhost:3000/admin`. Sign in with the account created in step 6.

## Important first-run actions

- Sample products are intentionally **inactive**. In `/admin → Products`, edit each SKU and details, upload your real product photos, then publish products you are allowed to represent. Stock sample images and descriptions are illustrative only; confirm technical claims, permissions and image rights before publishing.
- Set the representative's real WhatsApp number in international format (digits are recommended, e.g. country code + number with no `+`, spaces or punctuation). The number is read from `site_settings`, not hardcoded.
- Upload a real PDF catalog in **Catalog manager**. The public download button appears after the PDF URL is saved.
- Add actual phone/email/social links and profile photo. Use public HTTPS image URLs served by the Supabase `dentaflex-media` bucket.
- Add/rename categories and ensure SKUs are unique.
- Set the canonical domain and production metadata in Vercel once deployed.

## Security model

- `site_settings`, `categories`, and `products` have RLS enabled.
- Anonymous users can select only published settings and active products/categories.
- All writes are restricted to authenticated users for whom `public.is_dentaflex_admin()` returns true; that function checks the `admin_users` allow-list.
- Storage objects in `dentaflex-media` are publicly readable because product images and catalog PDFs need public URLs. Inserts, updates and deletes require the admin allow-list.
- There is no service-role key in browser code. The anon/publishable key is safe to expose when RLS is correctly enabled.
- The upload UI limits files to 8 MB and accepts common image types and PDF. Storage bucket has matching MIME and size limits.
- Do not add a public account-creation form. To revoke access, delete the user's row from `admin_users` and disable/delete their Auth user.
- Public image URLs are expected to be public. Do not upload private patient data or confidential documents.

## Vercel deployment

1. Push this project to a private or public Git repository.
2. In Vercel, **Add New → Project**, import the repository.
3. Add `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` under Project Settings → Environment Variables for Production, Preview, and Development as needed.
4. Deploy. No redeploy is needed for ordinary content edits; the public page reads live Supabase data on page load.
5. In Supabase Auth URL configuration, add your production origin to **Site URL** and **Redirect URLs** (for example `https://your-domain.vercel.app/**`). This app uses email/password sign-in; no OAuth callback is needed.
6. Set the site's real title/description and social sharing image in the admin SEO section. Note: Next's static root metadata is a fallback; fully dynamic Open Graph metadata generated server-side would require an additional server-rendered metadata lookup.

## WhatsApp quote behavior

The generated message includes the selected product's localized name, exact SKU/reference, quantity, product's public image URL, customer contact details, clinic/company and optional note. Headings use WhatsApp-compatible `*asterisks*`, and the full message is URL-encoded. `wa.me` opens a draft; the customer must manually review and send it. Standard click-to-chat supports a URL in the text but **cannot automatically attach an image file**.

## Data / field notes

- Localized fields are JSON objects such as `{"en":"...","fr":"...","ar":"..."}`.
- `site_settings` has one row with ID `main`.
- Product/category ordering uses `sort_order`.
- `active=false` hides an item from the public site but leaves it editable in admin.
- The `translations` JSON field can store future translation overrides. The included public UI uses bundled baseline interface strings; full live replacement of every UI string from that JSON is not wired in this starter.
- The brand color/font settings are persisted in the database. Current CSS uses the DentaFlex design tokens; dynamic application of arbitrary brand color/font choices is not yet wired to the UI.
- Gallery uploads and product PDFs are stored and their URLs saved on product records. The current public product card shows the main image; gallery/PDF display can be extended as needed.

## Verification / limitations

The source is provided as a runnable project, but this environment has no configured Supabase project credentials and cannot execute an authenticated end-to-end cloud test. Before launch, run the setup above and verify:
1. Log into `/admin` with the allow-listed owner.
2. Change a phone or WhatsApp value and save; refresh the public site and confirm it updates.
3. Add a product, upload an image, save, then publish it; confirm it appears in the public catalogue and search.
4. Open its quote form and test English, French and Arabic drafts. Check the selected SKU, quantity, customer details and image URL; manually send a test message to a number you control.
5. Try an unprivileged Auth user and confirm they cannot write to tables or upload/delete files.
6. Test at phone/tablet/desktop widths and keyboard navigation.

## Troubleshooting

- “Connect Supabase first”: check `.env.local` names, then restart Next.js.
- Empty public catalogue: sample products are inactive by design; publish approved items in the admin.
- RLS / permission errors: verify the current auth user UUID exists in `public.admin_users`, and re-run the schema SQL if policies were edited.
- Image upload fails: check bucket exists, file type/size, and admin membership.
