revoke all on function public.create_booking_hold(text,timestamptz,integer,text,jsonb,boolean) from public, anon;
revoke all on function public.expire_unpaid_booking_holds() from public, anon, authenticated;
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.is_admin() from public, anon;
revoke all on function public.is_staff() from public, anon;
revoke all on function public.release_expired_holds_before_insert() from public, anon, authenticated;
revoke all on function public.request_booking_cancellation(uuid,text) from public, anon;
revoke all on function public.request_booking_reschedule(uuid,timestamptz) from public, anon;

grant execute on function public.create_booking_hold(text,timestamptz,integer,text,jsonb,boolean) to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_staff() to authenticated;
grant execute on function public.request_booking_cancellation(uuid,text) to authenticated;
grant execute on function public.request_booking_reschedule(uuid,timestamptz) to authenticated;
grant execute on function public.expire_unpaid_booking_holds() to service_role;
