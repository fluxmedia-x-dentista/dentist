-- Dental clinic website + appointment booking. Run this entire script in Supabase SQL Editor.
-- Clinic timezone: Africa/Casablanca.
create extension if not exists pgcrypto;
create extension if not exists btree_gist;

create table if not exists public.admin_users (user_id uuid primary key references auth.users(id) on delete cascade, created_at timestamptz not null default now());
create or replace function public.is_clinic_admin()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.admin_users where user_id=auth.uid()); $$;

create table if not exists public.clinic_settings (id integer primary key default 1 check(id=1),content jsonb not null default '{}'::jsonb,updated_at timestamptz not null default now());
create table if not exists public.clinic_services (
 id uuid primary key default gen_random_uuid(),title text not null unique,description text not null default '',
 duration_minutes integer not null default 30 check(duration_minutes between 10 and 240),price numeric(10,2),
 active boolean not null default true,sort_order integer not null default 0,created_at timestamptz not null default now()
);
create table if not exists public.working_hours (
 day_of_week integer primary key check(day_of_week between 0 and 6),enabled boolean not null default false,
 open_time time not null default '09:00',close_time time not null default '17:00',break_start time,break_end time,
 slot_interval_minutes integer not null default 30 check(slot_interval_minutes between 10 and 120)
);
create table if not exists public.blocked_periods (
 id uuid primary key default gen_random_uuid(),starts_at timestamptz not null,ends_at timestamptz not null,
 reason text not null default 'Unavailable',created_at timestamptz not null default now(),check(ends_at>starts_at)
);
create table if not exists public.appointments (
 id uuid primary key default gen_random_uuid(),patient_name text not null check(length(trim(patient_name)) between 2 and 120),
 phone text not null check(length(trim(phone)) between 5 and 40),email text,
 service_id uuid not null references public.clinic_services(id) on delete restrict,
 starts_at timestamptz not null,ends_at timestamptz not null,duration_minutes integer not null,
 language text not null default 'fr' check(language in ('fr','ar','en')),
 status text not null default 'pending' check(status in ('pending','confirmed','rejected','cancelled')),
 created_at timestamptz not null default now(),check(ends_at>starts_at)
);
create index if not exists appointments_starts_at_idx on public.appointments(starts_at);
create index if not exists blocked_periods_range_idx on public.blocked_periods(starts_at,ends_at);
do $$ begin
 alter table public.appointments add constraint appointments_no_overlapping_active_slots
 exclude using gist (tstzrange(starts_at,ends_at,'[)') with &&) where (status in ('pending','confirmed'));
exception when duplicate_object then null; end $$;

alter table public.admin_users enable row level security;
alter table public.clinic_settings enable row level security;
alter table public.clinic_services enable row level security;
alter table public.working_hours enable row level security;
alter table public.blocked_periods enable row level security;
alter table public.appointments enable row level security;
drop policy if exists "admins read own clinic admin row" on public.admin_users;
create policy "admins read own clinic admin row" on public.admin_users for select to authenticated using(user_id=auth.uid());
drop policy if exists "public reads clinic profile" on public.clinic_settings;
create policy "public reads clinic profile" on public.clinic_settings for select to anon,authenticated using(true);
drop policy if exists "admins manage clinic profile" on public.clinic_settings;
create policy "admins manage clinic profile" on public.clinic_settings for all to authenticated using(public.is_clinic_admin()) with check(public.is_clinic_admin());
drop policy if exists "public reads active clinic services" on public.clinic_services;
create policy "public reads active clinic services" on public.clinic_services for select to anon,authenticated using(active or public.is_clinic_admin());
drop policy if exists "admins manage clinic services" on public.clinic_services;
create policy "admins manage clinic services" on public.clinic_services for all to authenticated using(public.is_clinic_admin()) with check(public.is_clinic_admin());
drop policy if exists "public reads working hours" on public.working_hours;
create policy "public reads working hours" on public.working_hours for select to anon,authenticated using(enabled or public.is_clinic_admin());
drop policy if exists "admins manage working hours" on public.working_hours;
create policy "admins manage working hours" on public.working_hours for all to authenticated using(public.is_clinic_admin()) with check(public.is_clinic_admin());
drop policy if exists "admins manage blocked periods" on public.blocked_periods;
create policy "admins manage blocked periods" on public.blocked_periods for all to authenticated using(public.is_clinic_admin()) with check(public.is_clinic_admin());
drop policy if exists "admins read appointments" on public.appointments;
create policy "admins read appointments" on public.appointments for select to authenticated using(public.is_clinic_admin());
drop policy if exists "admins update appointments" on public.appointments;
create policy "admins update appointments" on public.appointments for update to authenticated using(public.is_clinic_admin()) with check(public.is_clinic_admin());
drop policy if exists "admins delete appointments" on public.appointments;
create policy "admins delete appointments" on public.appointments for delete to authenticated using(public.is_clinic_admin());
revoke all on public.appointments from anon,authenticated;
grant select,update,delete on public.appointments to authenticated;

-- Returns only free start times, never patient data.
create or replace function public.get_available_slots(p_date date,p_service_id uuid)
returns table(starts_at timestamptz) language plpgsql security definer set search_path=public
as $$
declare h public.working_hours%rowtype; svc public.clinic_services%rowtype; local_start timestamp; local_end timestamp; candidate timestamp; candidate_start timestamptz; candidate_end timestamptz;
begin
 if p_date < (now() at time zone 'Africa/Casablanca')::date then return; end if;
 select * into svc from public.clinic_services where id=p_service_id and active=true;
 if not found then return; end if;
 select * into h from public.working_hours where day_of_week=extract(dow from p_date)::integer and enabled=true;
 if not found then return; end if;
 local_start:=p_date+h.open_time; local_end:=p_date+h.close_time; candidate:=local_start;
 while candidate+make_interval(mins=>svc.duration_minutes)<=local_end loop
  candidate_start:=candidate at time zone 'Africa/Casablanca';
  candidate_end:=(candidate+make_interval(mins=>svc.duration_minutes)) at time zone 'Africa/Casablanca';
  if candidate_start>now()
   and (h.break_start is null or h.break_end is null or not(candidate::time<h.break_end and (candidate+make_interval(mins=>svc.duration_minutes))::time>h.break_start))
   and not exists(select 1 from public.blocked_periods b where tstzrange(b.starts_at,b.ends_at,'[)') && tstzrange(candidate_start,candidate_end,'[)'))
   and not exists(select 1 from public.appointments a where a.status in ('pending','confirmed') and tstzrange(a.starts_at,a.ends_at,'[)') && tstzrange(candidate_start,candidate_end,'[)'))
  then starts_at:=candidate_start;return next;end if;
  candidate:=candidate+make_interval(mins=>h.slot_interval_minutes);
 end loop;
end $$;

-- Inserts a pending request only after rechecking schedule and conflicts.
create or replace function public.request_appointment(p_patient_name text,p_phone text,p_email text,p_service_id uuid,p_starts_at timestamptz,p_language text default 'fr')
returns uuid language plpgsql security definer set search_path=public
as $$
declare svc public.clinic_services%rowtype;h public.working_hours%rowtype;local_start timestamp;local_end timestamp;local_date date;new_id uuid;
begin
 if length(trim(coalesce(p_patient_name,''))) not between 2 and 120 or length(trim(coalesce(p_phone,''))) not between 5 and 40 then raise exception 'INVALID_PATIENT_DETAILS';end if;
 if p_email is not null and length(p_email)>254 then raise exception 'INVALID_EMAIL';end if;
 if p_language not in ('fr','ar','en') then raise exception 'INVALID_LANGUAGE';end if;
 local_start:=p_starts_at at time zone 'Africa/Casablanca';local_date:=local_start::date;
 perform pg_advisory_xact_lock(hashtext('clinic-booking-'||local_date::text));
 select * into svc from public.clinic_services where id=p_service_id and active=true;
 if not found then raise exception 'SERVICE_UNAVAILABLE';end if;
 select * into h from public.working_hours where day_of_week=extract(dow from local_date)::integer and enabled=true;
 if not found then raise exception 'SLOT_UNAVAILABLE';end if;
 local_end:=local_start+make_interval(mins=>svc.duration_minutes);
 if local_start::time<h.open_time or local_end::time>h.close_time or local_start<=(now() at time zone 'Africa/Casablanca') then raise exception 'SLOT_UNAVAILABLE';end if;
 if mod((extract(epoch from(local_start::time-h.open_time))/60)::integer,h.slot_interval_minutes)<>0 then raise exception 'SLOT_UNAVAILABLE';end if;
 if h.break_start is not null and h.break_end is not null and local_start::time<h.break_end and local_end::time>h.break_start then raise exception 'SLOT_UNAVAILABLE';end if;
 if exists(select 1 from public.blocked_periods b where tstzrange(b.starts_at,b.ends_at,'[)') && tstzrange(p_starts_at,p_starts_at+make_interval(mins=>svc.duration_minutes),'[)')) then raise exception 'SLOT_UNAVAILABLE';end if;
 if exists(select 1 from public.appointments a where a.status in ('pending','confirmed') and tstzrange(a.starts_at,a.ends_at,'[)') && tstzrange(p_starts_at,p_starts_at+make_interval(mins=>svc.duration_minutes),'[)')) then raise exception 'SLOT_UNAVAILABLE';end if;
 insert into public.appointments(patient_name,phone,email,service_id,starts_at,ends_at,duration_minutes,language,status)
 values(trim(p_patient_name),trim(p_phone),nullif(trim(coalesce(p_email,'')),''),p_service_id,p_starts_at,p_starts_at+make_interval(mins=>svc.duration_minutes),svc.duration_minutes,p_language,'pending') returning id into new_id;
 return new_id;
exception when exclusion_violation then raise exception 'SLOT_UNAVAILABLE';end $$;
revoke all on function public.get_available_slots(date,uuid) from public;
grant execute on function public.get_available_slots(date,uuid) to anon,authenticated;
revoke all on function public.request_appointment(text,text,text,uuid,timestamptz,text) from public;
grant execute on function public.request_appointment(text,text,text,uuid,timestamptz,text) to anon,authenticated;

insert into public.clinic_settings(id,content) values(1,'{"name":"Dr. Your Name","clinic":"Cabinet Dentaire","phone":"+212 6 00 00 00 00","email":"contact@cabinet-dentaire.ma","address":"Votre adresse, Maroc","tagline":"Des soins dentaires personnalisés dans un cadre rassurant.","accent":"#2a8c83","hero_image":"","profile_image":"","about":"Une approche attentive, des conseils clairs et des soins adaptés à chaque patient."}'::jsonb) on conflict(id) do nothing;
insert into public.clinic_services(title,description,duration_minutes,active,sort_order) values
('Consultation dentaire','Examen initial et plan de soins personnalisé.',30,true,1),('Détartrage','Nettoyage professionnel et conseils de prévention.',30,true,2),
('Soins conservateurs','Soins des caries et restauration dentaire.',45,true,3),('Urgence dentaire','Évaluation rapide en cas de douleur ou d’inconfort.',30,true,4),
('Esthétique dentaire','Conseils et soins pour un sourire harmonieux.',45,true,5),('Contrôle de routine','Suivi régulier de votre santé bucco-dentaire.',20,true,6)
on conflict do nothing;
insert into public.working_hours(day_of_week,enabled,open_time,close_time,break_start,break_end,slot_interval_minutes) values
(0,false,'09:00','17:00',null,null,30),(1,true,'09:00','18:00','12:30','14:00',30),(2,true,'09:00','18:00','12:30','14:00',30),(3,true,'09:00','18:00','12:30','14:00',30),(4,true,'09:00','18:00','12:30','14:00',30),(5,true,'09:00','18:00','12:30','14:00',30),(6,true,'09:00','13:00',null,null,30)
on conflict(day_of_week) do nothing;


-- Public image bucket used by the clinic profile's hero and dentist photos.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('clinic-images', 'clinic-images', true, 5242880, array['image/jpeg','image/png','image/webp','image/gif','image/avif'])
on conflict (id) do update set public = true, file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif','image/avif'];

drop policy if exists "Public can view clinic images" on storage.objects;
create policy "Public can view clinic images" on storage.objects
for select to anon, authenticated using (bucket_id = 'clinic-images');

drop policy if exists "Clinic admins upload clinic images" on storage.objects;
create policy "Clinic admins upload clinic images" on storage.objects
for insert to authenticated with check (bucket_id = 'clinic-images' and public.is_clinic_admin());

drop policy if exists "Clinic admins update clinic images" on storage.objects;
create policy "Clinic admins update clinic images" on storage.objects
for update to authenticated using (bucket_id = 'clinic-images' and public.is_clinic_admin())
with check (bucket_id = 'clinic-images' and public.is_clinic_admin());

drop policy if exists "Clinic admins delete clinic images" on storage.objects;
create policy "Clinic admins delete clinic images" on storage.objects
for delete to authenticated using (bucket_id = 'clinic-images' and public.is_clinic_admin());
