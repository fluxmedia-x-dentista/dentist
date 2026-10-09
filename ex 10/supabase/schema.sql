-- DentaFlex schema for Supabase (PostgreSQL)
create extension if not exists pgcrypto;

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create or replace function public.is_dentaflex_admin()
returns boolean language sql stable security definer
set search_path = public
as $$
  select exists (select 1 from public.admin_users where user_id = auth.uid());
$$;

revoke all on function public.is_dentaflex_admin() from public;
grant execute on function public.is_dentaflex_admin() to anon, authenticated;

create table if not exists public.site_settings (
  id text primary key default 'main' check (id = 'main'),
  brand_name text not null default 'DentaFlex',
  representative_name text not null default 'Your Dental Representative',
  role text not null default 'Dental Equipment Sales Representative',
  company_name text not null default 'DentaFlex',
  bio jsonb not null default '{}'::jsonb,
  location text not null default 'Morocco',
  phone text not null default '',
  whatsapp text not null default '',
  email text not null default '',
  profile_photo_url text not null default '',
  logo_url text not null default '',
  catalog_url text not null default '',
  hero_title jsonb not null default '{}'::jsonb,
  hero_subtitle jsonb not null default '{}'::jsonb,
  about_title jsonb not null default '{}'::jsonb,
  about_text jsonb not null default '{}'::jsonb,
  experience_years text not null default '',
  service_area text not null default 'Morocco',
  primary_button jsonb not null default '{}'::jsonb,
  footer_text jsonb not null default '{}'::jsonb,
  brand_color text not null default '#153e32',
  accent_color text not null default '#d8ed8c',
  font_family text not null default 'DM Sans',
  seo_title text not null default 'DentaFlex | Dental Equipment',
  seo_description text not null default 'Dental equipment for modern practices.',
  social_image_url text not null default '',
  instagram text not null default '',
  facebook text not null default '',
  linkedin text not null default '',
  other_social text not null default '',
  translations jsonb not null default '{}'::jsonb,
  is_published boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name jsonb not null default '{}'::jsonb,
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name jsonb not null default '{}'::jsonb,
  description jsonb not null default '{}'::jsonb,
  sku text not null unique,
  category_id uuid references public.categories(id) on delete set null,
  price numeric(12,2),
  quote_only boolean not null default true,
  image_url text,
  gallery_urls jsonb not null default '[]'::jsonb,
  pdf_url text,
  active boolean not null default false,
  featured boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint products_price_nonnegative check (price is null or price >= 0),
  constraint products_sku_not_blank check (length(trim(sku)) > 0)
);

create index if not exists products_active_sort_idx on public.products(active, sort_order);
create index if not exists products_category_idx on public.products(category_id);
create index if not exists products_sku_idx on public.products(sku);
create index if not exists categories_active_sort_idx on public.categories(active, sort_order);
create index if not exists site_settings_published_idx on public.site_settings(is_published);

alter table public.admin_users enable row level security;
alter table public.site_settings enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;

drop policy if exists "admins can read admin list" on public.admin_users;
create policy "admins can read admin list" on public.admin_users for select to authenticated using (public.is_dentaflex_admin());

drop policy if exists "public reads published settings" on public.site_settings;
create policy "public reads published settings" on public.site_settings for select to anon, authenticated using (is_published or public.is_dentaflex_admin());
drop policy if exists "admins manage settings" on public.site_settings;
create policy "admins manage settings" on public.site_settings for all to authenticated using (public.is_dentaflex_admin()) with check (public.is_dentaflex_admin());

drop policy if exists "public reads active categories" on public.categories;
create policy "public reads active categories" on public.categories for select to anon, authenticated using (active or public.is_dentaflex_admin());
drop policy if exists "admins manage categories" on public.categories;
create policy "admins manage categories" on public.categories for all to authenticated using (public.is_dentaflex_admin()) with check (public.is_dentaflex_admin());

drop policy if exists "public reads active products" on public.products;
create policy "public reads active products" on public.products for select to anon, authenticated using (active or public.is_dentaflex_admin());
drop policy if exists "admins manage products" on public.products;
create policy "admins manage products" on public.products for all to authenticated using (public.is_dentaflex_admin()) with check (public.is_dentaflex_admin());

-- Public bucket is required for public product image URLs and the PDF catalog.
-- Uploads/deletes are restricted to authenticated members of admin_users.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('dentaflex-media', 'dentaflex-media', true, 8388608,
  array['image/jpeg','image/png','image/webp','image/avif','application/pdf'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "public can view dentaflex media" on storage.objects;
create policy "public can view dentaflex media" on storage.objects for select to anon, authenticated using (bucket_id = 'dentaflex-media');
drop policy if exists "admins upload dentaflex media" on storage.objects;
create policy "admins upload dentaflex media" on storage.objects for insert to authenticated with check (bucket_id = 'dentaflex-media' and public.is_dentaflex_admin());
drop policy if exists "admins update dentaflex media" on storage.objects;
create policy "admins update dentaflex media" on storage.objects for update to authenticated using (bucket_id = 'dentaflex-media' and public.is_dentaflex_admin()) with check (bucket_id = 'dentaflex-media' and public.is_dentaflex_admin());
drop policy if exists "admins delete dentaflex media" on storage.objects;
create policy "admins delete dentaflex media" on storage.objects for delete to authenticated using (bucket_id = 'dentaflex-media' and public.is_dentaflex_admin());

-- Initial public settings. Safe to re-run; does not overwrite existing owner edits.
insert into public.site_settings (id, brand_name, representative_name, role, company_name, location, service_area,
  hero_title, hero_subtitle, about_title, about_text, primary_button, footer_text, seo_title, seo_description)
values ('main','DentaFlex','Your Dental Representative','Dental Equipment Sales Representative','DentaFlex','Morocco','Morocco',
  '{"en":"Better tools. Better care.","fr":"De meilleurs outils. De meilleurs soins.","ar":"أدوات أفضل. رعاية أفضل."}',
  '{"en":"Thoughtfully selected dental equipment, dependable guidance, and a relationship built around your practice.","fr":"Des équipements dentaires sélectionnés avec soin, des conseils fiables et une relation pensée pour votre cabinet.","ar":"معدات أسنان مختارة بعناية، وإرشاد موثوق، وشراكة تضع عيادتك في المقام الأول."}',
  '{"en":"Good equipment starts with good advice.","fr":"Le bon équipement commence par le bon conseil.","ar":"المعدات المناسبة تبدأ بالنصيحة المناسبة."}',
  '{"en":"I help dental professionals find dependable equipment that fits their workflow, standards, and ambitions.","fr":"J’accompagne les professionnels dentaires dans le choix d’équipements fiables, adaptés à leurs méthodes et à leurs ambitions.","ar":"أساعد أخصائيي طب الأسنان في اختيار معدات موثوقة تناسب أسلوب عملهم وطموحاتهم."}',
  '{"en":"Explore products","fr":"Voir les produits","ar":"استكشف المنتجات"}',
  '{"en":"Equipment that supports exceptional care.","fr":"Des équipements au service de soins d’exception.","ar":"معدات تدعم رعاية استثنائية."}',
  'DentaFlex | Dental Equipment','Thoughtfully selected dental equipment and dependable guidance for modern dental practices.')
on conflict (id) do nothing;

insert into public.categories (name, sort_order, active) values
 ('{"en":"Handpieces","fr":"Pièces à main","ar":"قبضات الأسنان"}',0,true),
 ('{"en":"Sterilization","fr":"Stérilisation","ar":"التعقيم"}',1,true),
 ('{"en":"Clinical essentials","fr":"Essentiels cliniques","ar":"مستلزمات سريرية"}',2,true)
on conflict do nothing;

-- Seed sample products with realistic catalogue-style data and non-branded illustrative images.
-- They are hidden by default until the owner reviews/approves details and activates them.
insert into public.products (name, description, sku, category_id, price, quote_only, image_url, active, featured, sort_order)
select '{"en":"LED Curing Light","fr":"Lampe à photopolymériser LED","ar":"مصباح معالجة ضوئي LED"}',
       '{"en":"Compact cordless curing light designed for everyday restorative workflows. Confirm wavelength and output specifications with the representative.","fr":"Lampe sans fil compacte conçue pour les soins restaurateurs quotidiens. Confirmez les caractéristiques auprès du représentant.","ar":"مصباح معالجة لاسلكي مدمج للاستخدام اليومي. يرجى تأكيد المواصفات مع الممثل."}',
       'DF-LIGHT-100', id, null, true, 'https://images.unsplash.com/photo-1609840114035-3c981b782dfe?auto=format&fit=crop&w=1000&q=85', false, true, 0
from public.categories where name->>'en'='Clinical essentials' limit 1
on conflict (sku) do nothing;

insert into public.products (name, description, sku, category_id, price, quote_only, image_url, active, featured, sort_order)
select '{"en":"High-Speed Handpiece","fr":"Turbine haute vitesse","ar":"قبضة عالية السرعة"}',
       '{"en":"Ergonomic high-speed handpiece option for precision procedures. Ask for compatible couplings and technical details.","fr":"Pièce à main ergonomique pour les procédures de précision. Demandez les raccords compatibles et les détails techniques.","ar":"قبضة مريحة للإجراءات الدقيقة. استفسر عن الوصلات المتوافقة والتفاصيل التقنية."}',
       'DF-HP-220', id, null, true, 'https://images.unsplash.com/photo-1606811971618-4486d14f3f99?auto=format&fit=crop&w=1000&q=85', false, false, 1
from public.categories where name->>'en'='Handpieces' limit 1
on conflict (sku) do nothing;

insert into public.products (name, description, sku, category_id, price, quote_only, image_url, active, featured, sort_order)
select '{"en":"Instrument Sterilization Pouches","fr":"Sachets de stérilisation","ar":"أكياس تعقيم الأدوات"}',
       '{"en":"Everyday sterilization consumable for organized instrument processing. Verify pouch sizes and applicable standards before ordering.","fr":"Consommable de stérilisation pour un traitement organisé des instruments. Vérifiez les dimensions et normes avant commande.","ar":"مستهلكات تعقيم للاستخدام اليومي. تحقق من الأحجام والمعايير قبل الطلب."}',
       'DF-STER-310', id, null, true, 'https://images.unsplash.com/photo-1584982751601-97dcc096659c?auto=format&fit=crop&w=1000&q=85', false, false, 2
from public.categories where name->>'en'='Sterilization' limit 1
on conflict (sku) do nothing;

-- FIRST ADMIN SETUP (after creating a user in Supabase Auth dashboard):
-- replace the UUID with that user's auth.users.id, then execute:
-- insert into public.admin_users(user_id) values ('00000000-0000-0000-0000-000000000000');
-- Disable public sign-ups in Supabase Auth > Settings > User Signups.
