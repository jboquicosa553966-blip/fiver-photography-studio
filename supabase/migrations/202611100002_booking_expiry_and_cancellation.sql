create or replace function public.release_expired_holds_before_insert()
returns trigger language plpgsql security definer set search_path=public
as $$ begin
 update public.bookings set status='expired',updated_at=now()
 where status='pending_payment' and payment_due_at < now();
 return new;
end $$;
drop trigger if exists release_expired_holds on public.bookings;
create trigger release_expired_holds before insert on public.bookings
for each statement execute function public.release_expired_holds_before_insert();

create or replace function public.request_booking_cancellation(p_booking_id uuid,p_reason text default '')
returns public.bookings language plpgsql security definer set search_path=public
as $$
declare v_booking public.bookings%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select * into v_booking from public.bookings where id=p_booking_id and user_id=auth.uid() for update;
 if not found then raise exception 'Booking not found'; end if;
 if v_booking.status not in ('pending_payment','confirmed') then raise exception 'This booking cannot be cancelled'; end if;
 if v_booking.starts_at <= now() then raise exception 'Past or ongoing sessions cannot be cancelled online'; end if;
 update public.bookings set status='cancelled',cancelled_at=now(),cancellation_reason=left(coalesce(p_reason,''),500),updated_at=now() where id=p_booking_id returning * into v_booking;
 insert into public.service_requests(user_id,request_type,status,details,amount)
 values(auth.uid(),'refund','received',jsonb_build_object('booking_id',p_booking_id,'reference',v_booking.reference,'notice_hours',extract(epoch from (v_booking.starts_at-now()))/3600,'policy','Staff review required; no automatic refund issued'),v_booking.paid_amount);
 return v_booking;
end $$;
grant execute on function public.request_booking_cancellation(uuid,text) to authenticated;
