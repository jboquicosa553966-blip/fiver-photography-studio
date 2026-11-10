create extension if not exists pgcrypto;
create extension if not exists btree_gist;

do $$ begin
  create type public.user_role as enum ('customer','staff','admin');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.booking_status as enum ('pending_payment','confirmed','selecting_photos','editing','delivered','cancelled','expired','refunded');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.payment_status as enum ('pending','paid','failed','refunded','partially_refunded');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  phone text,
  role public.user_role not null default 'customer',
  marketing_consent boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles where id=auth.uid() and role in ('staff','admin')) $$;
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='admin') $$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public
as $$
begin
  insert into public.profiles(id,full_name,phone,marketing_consent)
  values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),new.raw_user_meta_data->>'phone',coalesce((new.raw_user_meta_data->>'marketing_consent')::boolean,false))
  on conflict(id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create table if not exists public.packages (
  slug text primary key,
  name text not null,
  duration_minutes integer not null check(duration_minutes > 0 and duration_minutes <= 120),
  base_price integer not null check(base_price >= 0),
  min_people integer not null default 1,
  max_people integer,
  active boolean not null default true
);
insert into public.packages(slug,name,duration_minutes,base_price,min_people,max_people) values
('frame-of-you','Frame of You',60,599,1,1),
('frames-of-us','Frames of Us',60,899,2,2),
('frames-together','Frames Together',90,1399,3,6),
('frames-of-brands','Frames of Brands',120,1260,1,null),
('frames-of-vision','Frames of Vision',120,2200,1,null)
on conflict(slug) do update set name=excluded.name,duration_minutes=excluded.duration_minutes,base_price=excluded.base_price,min_people=excluded.min_people,max_people=excluded.max_people;

create table if not exists public.addons (
  slug text primary key,
  name text not null,
  unit_price integer not null check(unit_price >= 0),
  active boolean not null default true
);
insert into public.addons(slug,name,unit_price) values
('raw-digital','All unedited digital soft copies',300),
('extra-hour','Additional hour with studio and photographer',600),
('extra-edited-photo','Additional professionally edited photo',75),
('express-editing','Express 24-hour editing',250),
('extra-4r-print','Additional 4R print',35),
('advanced-retouching','Advanced retouching per photo',150),
('wardrobe-rental','Special costume / wardrobe rental',200),
('cleanup-fee','Cleanup fee for messy shoots',200)
on conflict(slug) do update set name=excluded.name,unit_price=excluded.unit_price;

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  reference text not null unique,
  user_id uuid not null references auth.users(id) on delete restrict,
  package_slug text not null references public.packages(slug),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  occupied_slot tstzrange generated always as (tstzrange(starts_at,to_timestamp(extract(epoch from ends_at) + 900),'[)')) stored,
  party_size integer not null default 1 check(party_size > 0),
  concept text,
  subtotal integer not null check(subtotal >= 0),
  reservation_fee integer not null check(reservation_fee >= 0),
  amount_due_now integer not null check(amount_due_now >= 0),
  paid_amount integer not null default 0 check(paid_amount >= 0),
  status public.booking_status not null default 'pending_payment',
  payment_due_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint booking_time_positive check(ends_at > starts_at),
  constraint booking_no_overlap exclude using gist(occupied_slot with &&)
    where(status in ('pending_payment','confirmed','selecting_photos','editing'))
);

create index if not exists bookings_user_date_idx on public.bookings(user_id,starts_at desc);
create index if not exists bookings_status_date_idx on public.bookings(status,starts_at);

create table if not exists public.booking_addons (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  addon_slug text not null references public.addons(slug),
  quantity integer not null check(quantity > 0),
  unit_price integer not null,
  line_total integer not null
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  provider text not null default 'paymongo',
  provider_session_id text unique,
  provider_payment_id text,
  amount integer not null check(amount > 0),
  currency text not null default 'PHP',
  status public.payment_status not null default 'pending',
  checkout_url text,
  paid_at timestamptz,
  raw_provider_data jsonb,
  created_at timestamptz not null default now()
);
create index if not exists payments_booking_idx on public.payments(booking_id);

create table if not exists public.webhook_events (
  provider_event_id text primary key,
  event_type text not null,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  payload jsonb not null
);

create table if not exists public.galleries (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'selecting_photos' check(status in ('selecting_photos','editing','delivered','expired')),
  expires_at timestamptz not null default now()+interval '30 days',
  reactivated_once boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.gallery_photos (
  id uuid primary key default gen_random_uuid(),
  gallery_id uuid not null references public.galleries(id) on delete cascade,
  storage_path text not null,
  preview_path text,
  selected boolean not null default false,
  delivered boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.service_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  request_type text not null check(request_type in ('voucher','subscription','studio_rental','support','refund','guarantee','print_order','referral')),
  status text not null default 'received',
  details jsonb not null default '{}'::jsonb,
  amount integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  rating integer not null check(rating between 1 and 5),
  review_text text not null,
  consent_to_publish boolean not null default false,
  is_approved boolean not null default false,
  created_at timestamptz not null default now(),
  unique(booking_id,user_id)
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id),
  action text not null,
  entity_type text not null,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.create_booking_hold(
  p_package_slug text,
  p_starts_at timestamptz,
  p_party_size integer default 1,
  p_concept text default '',
  p_addons jsonb default '[]'::jsonb,
  p_pay_full boolean default false
) returns public.bookings
language plpgsql security definer set search_path=public
as $$
declare
  v_uid uuid := auth.uid();
  v_pkg public.packages%rowtype;
  v_local_start timestamp;
  v_end timestamptz;
  v_total integer;
  v_fee integer;
  v_due integer;
  v_booking public.bookings%rowtype;
  v_item jsonb;
  v_addon public.addons%rowtype;
  v_qty integer;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  select * into v_pkg from public.packages where slug=p_package_slug and active;
  if not found then raise exception 'Package unavailable'; end if;
  if p_party_size < v_pkg.min_people or (v_pkg.max_people is not null and p_party_size > v_pkg.max_people) then
    raise exception 'Invalid party size for this package';
  end if;
  v_local_start := p_starts_at at time zone 'Asia/Manila';
  if p_starts_at <= now() then raise exception 'Choose a future time'; end if;
  if extract(dow from v_local_start)=0 then raise exception 'The studio is closed on Sundays'; end if;
  if v_local_start::time < time '12:00' or (v_local_start + make_interval(mins=>v_pkg.duration_minutes))::time > time '20:00' then
    raise exception 'Session must be between 12:00 PM and 8:00 PM';
  end if;
  v_end := p_starts_at + make_interval(mins=>v_pkg.duration_minutes);
  v_total := v_pkg.base_price;
  if jsonb_typeof(coalesce(p_addons,'[]'::jsonb)) <> 'array' then raise exception 'Invalid add-ons'; end if;
  for v_item in select * from jsonb_array_elements(coalesce(p_addons,'[]'::jsonb)) loop
    select * into v_addon from public.addons where slug=v_item->>'slug' and active;
    if not found then raise exception 'Invalid add-on'; end if;
    v_qty := greatest(1,least(100,coalesce((v_item->>'quantity')::integer,1)));
    v_total := v_total + v_addon.unit_price*v_qty;
  end loop;
  v_fee := ceil(v_total*0.30);
  v_due := case when p_pay_full then v_total else v_fee end;
  insert into public.bookings(reference,user_id,package_slug,starts_at,ends_at,party_size,concept,subtotal,reservation_fee,amount_due_now,payment_due_at)
  values('FVR-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),v_uid,p_package_slug,p_starts_at,v_end,p_party_size,left(coalesce(p_concept,''),1500),v_total,v_fee,v_due,now()+interval '15 minutes')
  returning * into v_booking;
  for v_item in select * from jsonb_array_elements(coalesce(p_addons,'[]'::jsonb)) loop
    select * into v_addon from public.addons where slug=v_item->>'slug';
    v_qty := greatest(1,least(100,coalesce((v_item->>'quantity')::integer,1)));
    insert into public.booking_addons(booking_id,addon_slug,quantity,unit_price,line_total)
    values(v_booking.id,v_addon.slug,v_qty,v_addon.unit_price,v_addon.unit_price*v_qty);
  end loop;
  return v_booking;
exception when exclusion_violation then
  raise exception 'That time was just booked. Please choose another slot.';
end $$;

create or replace function public.expire_unpaid_booking_holds()
returns integer language plpgsql security definer set search_path=public
as $$
declare v_count integer;
begin
  update public.bookings set status='expired',updated_at=now()
  where status='pending_payment' and payment_due_at < now()
    and not exists(select 1 from public.payments p where p.booking_id=bookings.id and p.status='paid');
  get diagnostics v_count=row_count;
  return v_count;
end $$;

alter table public.profiles enable row level security;
alter table public.bookings enable row level security;
alter table public.booking_addons enable row level security;
alter table public.payments enable row level security;
alter table public.galleries enable row level security;
alter table public.gallery_photos enable row level security;
alter table public.service_requests enable row level security;
alter table public.reviews enable row level security;
alter table public.audit_logs enable row level security;

create policy "profile read self or staff" on public.profiles for select to authenticated using(id=auth.uid() or public.is_staff());
create policy "profile update self" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy "customer reads own bookings" on public.bookings for select to authenticated using(user_id=auth.uid() or public.is_staff());
create policy "customer reads own booking addons" on public.booking_addons for select to authenticated using(exists(select 1 from public.bookings b where b.id=booking_id and (b.user_id=auth.uid() or public.is_staff())));
create policy "customer reads own payments" on public.payments for select to authenticated using(exists(select 1 from public.bookings b where b.id=booking_id and (b.user_id=auth.uid() or public.is_staff())));
create policy "owner or staff reads gallery" on public.galleries for select to authenticated using(owner_id=auth.uid() or public.is_staff());
create policy "owner or staff reads gallery photos" on public.gallery_photos for select to authenticated using(exists(select 1 from public.galleries g where g.id=gallery_id and (g.owner_id=auth.uid() or public.is_staff())));
create policy "user creates own requests" on public.service_requests for insert to authenticated with check(user_id=auth.uid());
create policy "user reads own requests" on public.service_requests for select to authenticated using(user_id=auth.uid() or public.is_staff());
create policy "public approved reviews" on public.reviews for select to anon,authenticated using(is_approved and consent_to_publish or user_id=auth.uid() or public.is_staff());
create policy "customer reads own audit" on public.audit_logs for select to authenticated using(actor_id=auth.uid() or public.is_admin());

grant select on public.packages,public.addons to anon,authenticated;
grant select,update on public.profiles to authenticated;
grant select on public.bookings,public.booking_addons,public.payments,public.galleries,public.gallery_photos,public.service_requests,public.reviews,public.audit_logs to authenticated;
grant insert on public.service_requests to authenticated;
grant execute on function public.create_booking_hold(text,timestamptz,integer,text,jsonb,boolean) to authenticated;
grant execute on function public.expire_unpaid_booking_holds() to service_role;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('client-galleries','client-galleries',false,26214400,array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;

create policy "gallery owner and staff can read objects" on storage.objects for select to authenticated
using(bucket_id='client-galleries' and (public.is_staff() or exists(
  select 1 from public.galleries g where g.owner_id=auth.uid()
  and (storage.objects.name like g.id::text||'/%')
)));
create policy "staff can upload gallery objects" on storage.objects for insert to authenticated
with check(bucket_id='client-galleries' and public.is_staff());
create policy "staff can update gallery objects" on storage.objects for update to authenticated
using(bucket_id='client-galleries' and public.is_staff())
with check(bucket_id='client-galleries' and public.is_staff());

