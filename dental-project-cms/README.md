# Dental Project — website + Supabase CMS

A responsive dental representative website inspired by the supplied `Naji Sedki · Dental Project` design, rebuilt as a Next.js app with a Supabase database and protected admin dashboard. The public site includes the profile/hero, company story, product categories and searchable product catalog, services, catalog download, contact details, social links, and WhatsApp quotation workflow.

## Tech stack
- Next.js 14 / React / TypeScript
- Supabase Auth for admin sign-in
- Supabase Postgres for site settings, products, categories, services, and optional quote-request storage
- Supabase Storage for profile/product images and PDF catalog files
- Responsive desktop/mobile styling

## 1. Create the database
1. Create a project at https://supabase.com.
2. Open **SQL Editor → New query**.
3. Paste and run the complete `supabase/schema.sql` file.
4. The script creates the tables, public/admin row-level security policies, starter profile content, starter categories/services, and the `dental-project-media` public media bucket.

## 2. Create an administrator
1. In Supabase, open **Authentication → Users → Add user** and create the email/password that should manage the site. Confirm the account if your Auth settings require it.
2. Copy that user's UUID from the user list.
3. In SQL Editor run the following, replacing the example UUID with the real one:

```sql
insert into public.admin_users (user_id)
values ('PASTE-AUTH-USER-UUID-HERE');
```

Only users listed in `public.admin_users` can write website data or upload media. Do not add public visitors to this table.

## 3. Configure local development
1. Copy `.env.example` to `.env.local`.
2. Fill in the Project URL and publishable/anon key from **Supabase → Project Settings → API**:

```env
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

3. Install dependencies and run the dev server:

```bash
npm install
npm run dev
```

Open `http://localhost:3000`; open `http://localhost:3000/admin` to sign in.

## 4. Deploy to Vercel
1. Push this project to your GitHub repository.
2. Import the repository in Vercel (framework preset: Next.js).
3. In **Vercel → Project → Settings → Environment Variables**, add `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` for Production and Preview as needed.
4. Redeploy after saving the variables.
5. Test the homepage and `/admin` on the deployed domain.

## What the admin can edit
- Representative name/title, company, contact details, market, experience, languages, hero tagline, profile/about copy, company description, mission, accent color
- Profile photo and PDF catalog uploads
- Social links
- Add/edit/delete/publish product categories
- Add/edit/delete/publish products, assign categories, add SKU, description, price/currency, image and featured status
- Add/edit/delete/publish services

Changes saved in the admin dashboard are read from Supabase by the public website. No code edit is required for routine content updates.

## Notes
- The WhatsApp number must be international format digits only, for example `2126XXXXXXXX`, without `+`, spaces, or punctuation.
- Starter contact details are examples/placeholders. Replace them in `/admin` before launch.
- Product entries start empty intentionally; add real product data and images in the admin panel. Starter categories and services are seeded by SQL.
- The enquiry form opens WhatsApp with a prefilled message. The `quote_requests` table and admin-only RLS policy are included if you later want a server-side form submission workflow; the current frontend does not store customer enquiries in the database.
- The media bucket is public so product/profile/catalog URLs can be displayed to visitors. Only approved admin accounts can upload, update, or delete files.
- Never place a Supabase service-role key in a `NEXT_PUBLIC_` environment variable or in browser code.
