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
 if v_booking.starts_at-now() < interval '24 hours' then raise exception 'Online cancellation requires at least 24 hours notice. Please contact the studio for assistance.'; end if;
 update public.bookings set status='cancelled',cancelled_at=now(),cancellation_reason=left(coalesce(p_reason,''),500),updated_at=now() where id=p_booking_id returning * into v_booking;
 insert into public.service_requests(user_id,request_type,status,details,amount)
 values(auth.uid(),'refund','received',jsonb_build_object('booking_id',p_booking_id,'reference',v_booking.reference,'notice_hours',extract(epoch from (v_booking.starts_at-now()))/3600,'policy','Cancellation received at least 24 hours before session. Staff must review any refund; no automatic refund issued.'),v_booking.paid_amount);
 return v_booking;
end $$;

create or replace function public.request_booking_reschedule(p_booking_id uuid,p_new_start timestamptz)
returns public.bookings language plpgsql security definer set search_path=public
as $$
declare v_booking public.bookings%rowtype;
declare v_duration interval;
declare v_local timestamp;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select * into v_booking from public.bookings where id=p_booking_id and user_id=auth.uid() for update;
 if not found then raise exception 'Booking not found'; end if;
 if v_booking.status not in ('pending_payment','confirmed') then raise exception 'This booking cannot be rescheduled'; end if;
 if v_booking.starts_at-now() < interval '24 hours' then raise exception 'Rescheduling requires at least 24 hours notice. Please contact the studio.'; end if;
 if p_new_start <= now() then raise exception 'Choose a future date and time'; end if;
 v_duration:=v_booking.ends_at-v_booking.starts_at;
 v_local:=p_new_start at time zone 'Asia/Manila';
 if extract(dow from v_local)=0 then raise exception 'The studio is closed on Sundays'; end if;
 if v_local::time < time '12:00' or (v_local+v_duration)::time > time '20:00' then raise exception 'Session must be between 12:00 PM and 8:00 PM'; end if;
 update public.bookings set starts_at=p_new_start,ends_at=p_new_start+v_duration,updated_at=now()
 where id=p_booking_id returning * into v_booking;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,details)
 values(auth.uid(),'booking_rescheduled','booking',p_booking_id::text,jsonb_build_object('new_start',p_new_start));
 return v_booking;
exception when exclusion_violation then
 raise exception 'That time is already reserved. Please choose another slot.';
end $$;
grant execute on function public.request_booking_cancellation(uuid,text) to authenticated;
grant execute on function public.request_booking_reschedule(uuid,timestamptz) to authenticated;
