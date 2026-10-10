# Dental clinic website + appointment booking

A separate multilingual clinic website (French, Arabic/RTL, English) built with Next.js, TypeScript, and Supabase.

## Features
- Dentist/clinic profile, treatments, contact details, and responsive clinic landing page.
- Language switcher for French, Arabic (right-to-left), and English.
- Appointment requests with service durations and live available slots.
- Requests require manual approval. Pending and confirmed appointments both reserve their slot.
- Weekly working hours, breaks, closures, and custom blocked periods.
- Private dashboard at `/admin` for appointment approvals, schedule, services, blocked periods, and clinic profile.
- Supabase RPC rechecks availability at submission, uses a per-day advisory lock, and a Postgres exclusion constraint prevents overlapping pending/confirmed appointments.

## 1. Supabase database setup
1. Open the correct Supabase project and go to **SQL Editor → New query**.
2. Run the complete `supabase/schema.sql` file.
3. The SQL seeds example treatments and default working hours (Monday-Friday 09:00-18:00 with 12:30-14:00 break, Saturday 09:00-13:00, Sunday closed). Adjust these in `/admin`.
4. Create the administrator account under **Authentication → Users**.
5. Copy the auth user's UUID and run this in SQL Editor, replacing the UUID:

```sql
insert into public.admin_users(user_id) values ('PASTE-AUTH-USER-UUID-HERE');
```

Only users in `admin_users` can access dashboard data or manage the clinic. Public visitors cannot directly read patient appointment records; they use controlled database functions to request an appointment and see free slots.

> If this Supabase project already contains the earlier commercial website schema, take a backup first. This schema adds clinic-specific tables and leaves old tables in place, but the new website no longer uses the old product/catalog tables.

## 2. Environment variables
Set these locally in `.env.local` and in Vercel project environment variables:

```env
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY
```

Never put the Supabase service-role key in browser code or a `NEXT_PUBLIC_` variable.

## 3. Run locally
```bash
npm install
npm run dev
```
Open `http://localhost:3000` and `http://localhost:3000/admin`.

## 4. Deploy
Import this repository into Vercel with the project root set to `dental-project-cms`, configure the two Supabase environment variables, and redeploy. Verify the SQL schema is installed and create the admin user before enabling real bookings.

## Before launch
- Replace the dentist name, clinic name, address, phone, and email in the admin profile.
- Review treatment names and durations.
- Configure actual working hours, breaks, holidays, and time-off blocks.
- Test booking a slot, verify it disappears for a second visitor, and test reject/cancel behavior.
- Clinic time zone is set to `Africa/Casablanca`.
