-- TM-003 next governance hardening layer v1
-- Deterministic safety constraints for the initial repository-side build.
-- This file is intentionally separate from the migration while the schema is under review.

-- 1. Lock creation must occur only from a governed lockable state.
create or replace function public.tm003_create_booking_lock(
  p_booking_id uuid,
  p_snapshot jsonb,
  p_source_event_id uuid default null,
  p_actor_operator_id uuid default null
)
returns public.tm003_booking_locks
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_booking public.tm003_bookings%rowtype;
  v_lock public.tm003_booking_locks%rowtype;
  v_actor uuid;
  v_next_version integer;
begin
  select * into v_booking
  from public.tm003_bookings
  where id = p_booking_id
  for update;

  if not found then
    raise exception 'TM-003 booking not found: %', p_booking_id;
  end if;

  v_actor := coalesce(p_actor_operator_id, public.tm003_current_operator_id());
  if v_actor is null then
    raise exception 'TM-003 lock creation requires an authenticated operator';
  end if;

  if v_booking.status <> 'GOVERNANCE_LOCKED' then
    raise exception 'TM-003 booking must be GOVERNANCE_LOCKED before lock creation';
  end if;

  if v_booking.readiness_state <> 'READY_FOR_LOCK' then
    raise exception 'TM-003 booking must have READY_FOR_LOCK readiness before lock creation';
  end if;

  if not (v_booking.commercial_ready and v_booking.operational_ready) then
    raise exception 'TM-003 cannot create lock before commercial and operational readiness';
  end if;

  select coalesce(max(version), 0) + 1
  into v_next_version
  from public.tm003_booking_locks
  where booking_id = p_booking_id;

  if v_next_version > 1 and v_booking.latest_lock_id is null then
    raise exception 'TM-003 lock chain is inconsistent: missing latest lock';
  end if;

  insert into public.tm003_booking_locks(
    lock_id, booking_id, version, source_event_id, locked_by, snapshot, immutable
  ) values (
    'LCK-' || to_char(current_date, 'YYYYMMDD') || '-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,6)),
    p_booking_id, v_next_version, p_source_event_id, v_actor, p_snapshot, true
  ) returning * into v_lock;

  update public.tm003_bookings
  set latest_lock_id = v_lock.id,
      readiness_state = 'LOCKED'::tm003_readiness_state,
      updated_at = now()
  where id = p_booking_id;

  insert into public.tm003_audit_log(
    booking_id, actor_operator_id, action, new_data, metadata
  ) values (
    p_booking_id, v_actor, 'BOOKING_LOCK_CREATED',
    to_jsonb(v_lock), jsonb_build_object('version', v_next_version)
  );

  return v_lock;
end;
$$;

-- 2. Approval cannot be granted to an already approved request.
create or replace function public.tm003_approve_change(
  p_change_request_id uuid,
  p_actor_operator_id uuid default null,
  p_resolution text default null
)
returns public.tm003_change_requests
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_request public.tm003_change_requests%rowtype;
  v_actor uuid;
  v_role tm003_role_code;
begin
  select * into v_request
  from public.tm003_change_requests
  where id = p_change_request_id
  for update;

  if not found then
    raise exception 'TM-003 change request not found: %', p_change_request_id;
  end if;

  if v_request.approval_status <> 'PENDING' then
    raise exception 'TM-003 change request is not pending approval';
  end if;

  v_actor := coalesce(p_actor_operator_id, public.tm003_current_operator_id());
  if v_actor is null then
    raise exception 'TM-003 approval requires an authenticated operator';
  end if;

  select role_code
  into v_role
  from public.tm003_operators
  where id = v_actor and is_active = true;

  if v_role is null or public.tm003_role_rank(v_role) > public.tm003_role_rank('manager'::tm003_role_code) then
    raise exception 'TM-003 material change approval requires manager authority';
  end if;

  if v_request.change_class in ('COMMERCIAL_VARIATION','OPERATIONAL_EXCEPTION')
     and not v_request.approval_required then
    raise exception 'TM-003 material change cannot bypass approval requirement';
  end if;

  update public.tm003_change_requests
  set approval_status = 'APPROVED',
      approved_by = v_actor,
      approved_at = now(),
      validation_result = jsonb_build_object(
        'approved', true,
        'resolution', p_resolution,
        'validated_at', now()
      )
  where id = p_change_request_id
  returning * into v_request;

  insert into public.tm003_audit_log(
    booking_id, signal_id, actor_operator_id, action, new_data, metadata
  ) values (
    v_request.booking_id, v_request.signal_id, v_actor,
    'CHANGE_REQUEST_APPROVED', to_jsonb(v_request),
    jsonb_build_object('resolution', p_resolution)
  );

  return v_request;
end;
$$;

-- 3. Restrict the security-definer functions to trusted database roles.
revoke all on function public.tm003_transition_booking(uuid, tm003_booking_status, text, uuid) from public, anon, authenticated;
revoke all on function public.tm003_create_booking_lock(uuid, jsonb, uuid, uuid) from public, anon, authenticated;
revoke all on function public.tm003_request_change(uuid, text, jsonb, tm003_change_class, uuid, uuid, boolean) from public, anon, authenticated;
revoke all on function public.tm003_approve_change(uuid, uuid, text) from public, anon, authenticated;

-- Service role is intentionally the only direct execution path in this V1 database layer.
grant execute on function public.tm003_transition_booking(uuid, tm003_booking_status, text, uuid) to service_role;
grant execute on function public.tm003_create_booking_lock(uuid, jsonb, uuid, uuid) to service_role;
grant execute on function public.tm003_request_change(uuid, text, jsonb, tm003_change_class, uuid, uuid, boolean) to service_role;
grant execute on function public.tm003_approve_change(uuid, uuid, text) to service_role;
