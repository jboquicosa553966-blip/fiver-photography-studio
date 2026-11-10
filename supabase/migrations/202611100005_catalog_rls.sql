alter table public.packages enable row level security;
alter table public.addons enable row level security;
alter table public.webhook_events enable row level security;

drop policy if exists "Public can read active packages" on public.packages;
create policy "Public can read active packages"
on public.packages for select to anon, authenticated
using (active = true);

drop policy if exists "Public can read active addons" on public.addons;
create policy "Public can read active addons"
on public.addons for select to anon, authenticated
using (active = true);

revoke all on table public.webhook_events from anon, authenticated;
grant select on table public.packages, public.addons to anon, authenticated;
