-- Lock profile privilege escalation: customers may only edit their own contact fields.
revoke update on public.profiles from authenticated;
grant update(full_name,phone,marketing_consent,updated_at) on public.profiles to authenticated;

-- Allow staff to manage operational records. Staff role is assigned only by a trusted admin.
drop policy if exists "staff update bookings" on public.bookings;
create policy "staff update bookings" on public.bookings for update to authenticated
using(public.is_staff()) with check(public.is_staff());
drop policy if exists "staff update service requests" on public.service_requests;
create policy "staff update service requests" on public.service_requests for update to authenticated
using(public.is_staff()) with check(public.is_staff());
drop policy if exists "staff update galleries" on public.galleries;
create policy "staff update galleries" on public.galleries for update to authenticated
using(public.is_staff()) with check(public.is_staff());
drop policy if exists "staff update gallery photos" on public.gallery_photos;
create policy "staff update gallery photos" on public.gallery_photos for update to authenticated
using(public.is_staff()) with check(public.is_staff());
drop policy if exists "customer submits review for completed booking" on public.reviews;
create policy "customer submits review for completed booking" on public.reviews for insert to authenticated
with check(user_id=auth.uid() and exists(select 1 from public.bookings b where b.id=booking_id and b.user_id=auth.uid() and b.status='delivered'));
grant select on public.reviews to anon;
