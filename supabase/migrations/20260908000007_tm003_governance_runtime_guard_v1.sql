-- TM-003 governance runtime guard V1
-- Restores the minimum deterministic governance primitives required by the ordered TM-003 runtime
-- after the historical governance migration was reduced to a marker.
-- This is intentionally narrow; it does not replace the canonical booking foundation.

create or replace function public.tm003_booking_snapshot(p_booking_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select to_jsonb(b) - 'created_at' - 'updated_at'
  from public.tm003_bookings b
  where b.id = p_booking_id;
$$;

revoke execute on function public.tm003_booking_snapshot(uuid) from public, anon;
grant execute on function public.tm003_booking_snapshot(uuid) to authenticated, service_role;

create or replace function public.tm003_prevent_lock_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'TM-003 booking locks are immutable';
end;
$$;

drop trigger if exists tm003_booking_locks_immutable on public.tm003_booking_locks;
create trigger tm003_booking_locks_immutable
before update or delete on public.tm003_booking_locks
for each row execute function public.tm003_prevent_lock_mutation();
