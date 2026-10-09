-- Dental Project website CMS — run this entire file in Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.site_settings (
  id integer primary key default 1 check (id = 1),
  content jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  icon text default '✦',
  description text default '',
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  sku text unique,
  description text default '',
  category_id uuid references public.categories(id) on delete set null,
  price numeric(12,2),
  currency text not null default 'MAD',
  image_url text,
  active boolean not null default false,
  featured boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  title text not null unique,
  icon text default '✦',
  description text default '',
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
create table if not exists public.quote_requests (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null,
  phone text not null,
  email text,
  clinic text,
  product_id uuid references public.products(id) on delete set null,
  quantity integer not null default 1,
  message text,
  status text not null default 'new' check (status in ('new','contacted','closed')),
  created_at timestamptz not null default now()
);

create or replace function public.is_dental_project_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.admin_users where user_id = auth.uid()); $$;

alter table public.admin_users enable row level security;
alter table public.site_settings enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.services enable row level security;
alter table public.quote_requests enable row level security;

drop policy if exists "admin can read own admin row" on public.admin_users;
create policy "admin can read own admin row" on public.admin_users for select to authenticated using (user_id = auth.uid());
drop policy if exists "public reads site settings" on public.site_settings;
create policy "public reads site settings" on public.site_settings for select to anon, authenticated using (true);
drop policy if exists "admins manage site settings" on public.site_settings;
create policy "admins manage site settings" on public.site_settings for all to authenticated using (public.is_dental_project_admin()) with check (public.is_dental_project_admin());
drop policy if exists "public reads active categories" on public.categories;
create policy "public reads active categories" on public.categories for select to anon, authenticated using (active or public.is_dental_project_admin());
drop policy if exists "admins manage categories" on public.categories;
create policy "admins manage categories" on public.categories for all to authenticated using (public.is_dental_project_admin()) with check (public.is_dental_project_admin());
drop policy if exists "public reads active products" on public.products;
create policy "public reads active products" on public.products for select to anon, authenticated using (active or public.is_dental_project_admin());
drop policy if exists "admins manage products" on public.products;
create policy "admins manage products" on public.products for all to authenticated using (public.is_dental_project_admin()) with check (public.is_dental_project_admin());
drop policy if exists "public reads active services" on public.services;
create policy "public reads active services" on public.services for select to anon, authenticated using (active or public.is_dental_project_admin());
drop policy if exists "admins manage services" on public.services;
create policy "admins manage services" on public.services for all to authenticated using (public.is_dental_project_admin()) with check (public.is_dental_project_admin());
-- Quote forms use WhatsApp by default. This policy is ready if you later switch to DB-backed enquiries.
drop policy if exists "admins manage quote requests" on public.quote_requests;
create policy "admins manage quote requests" on public.quote_requests for all to authenticated using (public.is_dental_project_admin()) with check (public.is_dental_project_admin());

insert into public.site_settings (id, content) values (1, '{
  "name":"Naji Sedki", "role":"Commercial Representative", "company":"Dental Project",
  "phone":"+212 6 XX XX XX XX", "whatsapp":"212600000000", "email":"naji@dentalproject.ma",
  "website":"www.dentalproject.ma", "location":"Morocco", "experience":"6+ Years",
  "languages":"Arabic · French · English",
  "tagline":"Helping dental professionals find the right products, solutions, and services for their practice.",
  "about":"I work with dentists, clinics, laboratories, and dental professionals to understand their needs and provide suitable products and solutions from Dental Project. My role includes product consultation, commercial support, quotations, order follow-up, and long-term client relationships.",
  "company_about":"Dental Project supports dental professionals with products, equipment, materials, and solutions designed for modern dental practices.",
  "mission":"To equip dental practices with reliable products and responsive commercial support.",
  "profile_image":"", "catalog_url":"", "accent":"#2aa3a8",
  "socials":[{"label":"LinkedIn","name":"Naji Sedki","url":"https://linkedin.com"},{"label":"Instagram","name":"@dentalproject","url":"https://instagram.com"},{"label":"Facebook","name":"Dental Project","url":"https://facebook.com"}]
}'::jsonb) on conflict (id) do nothing;

insert into public.categories (name, icon, description, active, sort_order) values
('Dental Materials','🧪','Restorative and impression materials.',true,1),
('Dental Equipment','🦷','Units, chairs, and clinic equipment.',true,2),
('Implantology','🔩','Implant systems and surgical kits.',true,3),
('Prosthodontics','👑','Crowns, bridges, and laboratory supplies.',true,4),
('Orthodontics','😁','Brackets, wires, and aligner accessories.',true,5),
('Endodontics','🪥','Files, obturation, and irrigation.',true,6),
('Preventive Dentistry','🛡️','Fluoride, sealants, and hygiene.',true,7),
('Consumables','🧤','Everyday clinic supplies.',true,8),
('Digital Dentistry','💻','Scanners, CAD/CAM, and imaging.',true,9),
('Infection Control','🧼','Sterilization and disinfection.',true,10)
on conflict (name) do nothing;
insert into public.services (title,icon,description,active,sort_order) values
('Product Consultation','🩺','Helping dental professionals identify suitable products for their needs.',true,1),
('Product Demonstration','🎯','Presenting products and explaining their use and benefits.',true,2),
('Commercial Support','💼','Information, recommendations, pricing, and guidance.',true,3),
('Quotation Requests','📄','Commercial offers based on your requirements.',true,4),
('Order Follow-Up','📦','Support throughout the ordering process.',true,5),
('After-Sales Support','🤝','Follow-up and product-related questions.',true,6)
on conflict (title) do nothing;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('dental-project-media','dental-project-media',true,10485760,array['image/jpeg','image/png','image/webp','image/gif','application/pdf'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "public reads dental project media" on storage.objects;
create policy "public reads dental project media" on storage.objects for select to anon, authenticated using (bucket_id = 'dental-project-media');
drop policy if exists "admins upload dental project media" on storage.objects;
create policy "admins upload dental project media" on storage.objects for insert to authenticated with check (bucket_id = 'dental-project-media' and public.is_dental_project_admin());
drop policy if exists "admins update dental project media" on storage.objects;
create policy "admins update dental project media" on storage.objects for update to authenticated using (bucket_id = 'dental-project-media' and public.is_dental_project_admin()) with check (bucket_id = 'dental-project-media' and public.is_dental_project_admin());
drop policy if exists "admins delete dental project media" on storage.objects;
create policy "admins delete dental project media" on storage.objects for delete to authenticated using (bucket_id = 'dental-project-media' and public.is_dental_project_admin());

-- After creating your admin user in Supabase Authentication, run this with their actual UUID:
-- insert into public.admin_users (user_id) values ('PASTE-AUTH-USER-UUID-HERE');
