-- TM-003 deterministic mutation layer v1
-- Server-side governed operations. Intended to be invoked only by trusted server/service-role code.
-- No autonomous commercial approval; all material changes require explicit approval.

create or replace function public.tm003_transition_booking(
  p_booking_id uuid,
  p_to_status tm003_booking_status,
  p_reason text default null,
  p_actor_operator_id uuid default null
)
returns public.tm003_bookings
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_booking public.tm003_bookings%rowtype;
  v_actor uuid;
  v_allowed boolean := false;
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
    raise exception 'TM-003 transition requires an authenticated operator';
  end if;

  if v_booking.status = p_to_status then
    return v_booking;
  end if;

  v_allowed := case v_booking.status
    when 'ENQUIRY' then p_to_status in ('TENTATIVE','AWAITING_INFORMATION','CANCELLED','ON_HOLD')
    when 'TENTATIVE' then p_to_status in ('AWAITING_INFORMATION','AWAITING_ADVANCE','CONFIRMED','CANCELLED','ON_HOLD','EXCEPTION')
    when 'AWAITING_INFORMATION' then p_to_status in ('TENTATIVE','AWAITING_ADVANCE','CONFIRMED','CANCELLED','ON_HOLD','EXCEPTION')
    when 'AWAITING_ADVANCE' then p_to_status in ('CONFIRMED','CANCELLED','ON_HOLD','EXCEPTION')
    when 'CONFIRMED' then p_to_status in ('GOVERNANCE_LOCKED','ON_HOLD','CANCELLED','EXCEPTION')
    when 'GOVERNANCE_LOCKED' then p_to_status in ('PREPARING','ON_HOLD','EXCEPTION')
    when 'PREPARING' then p_to_status in ('READY','ON_HOLD','EXCEPTION')
    when 'READY' then p_to_status in ('LIVE','ON_HOLD','EXCEPTION')
    when 'LIVE' then p_to_status in ('CLOSING','EXCEPTION')
    when 'CLOSING' then p_to_status in ('COMPLETED','EXCEPTION')
    when 'COMPLETED' then false
    when 'CANCELLED' then false
    when 'ON_HOLD' then p_to_status in ('TENTATIVE','AWAITING_INFORMATION','AWAITING_ADVANCE','CONFIRMED','GOVERNANCE_LOCKED','PREPARING','READY','LIVE','CLOSING','CANCELLED','EXCEPTION')
    when 'EXCEPTION' then p_to_status in ('ON_HOLD','CANCELLED','TENTATIVE','AWAITING_INFORMATION','AWAITING_ADVANCE','CONFIRMED','GOVERNANCE_LOCKED','PREPARING','READY','LIVE','CLOSING')
    else false
  end;

  if not v_allowed then
    raise exception 'TM-003 invalid booking transition: % -> %', v_booking.status, p_to_status;
  end if;

  if p_to_status = 'GOVERNANCE_LOCKED' and not (
    v_booking.commercial_ready and v_booking.operational_ready and v_booking.readiness_state = 'READY_FOR_LOCK'
  ) then
    raise exception 'TM-003 booking is not ready for governance lock';
  end if;

  update public.tm003_bookings
  set status = p_to_status,
      readiness_state = case
        when p_to_status = 'GOVERNANCE_LOCKED' then 'LOCKED'::tm003_readiness_state
        when p_to_status in ('EXCEPTION','ON_HOLD') then 'EXCEPTION'::tm003_readiness_state
        when p_to_status in ('READY','LIVE') and execution_ready then 'EXECUTION_READY'::tm003_readiness_state
        else readiness_state
      end,
      updated_at = now()
  where id = p_booking_id
  returning * into v_booking;

  insert into public.tm003_audit_log(
    booking_id, actor_operator_id, action, previous_data, new_data, metadata
  ) values (
    p_booking_id, v_actor, 'BOOKING_STATUS_TRANSITION',
    jsonb_build_object('status', v_booking.status),
    jsonb_build_object('status', p_to_status),
    jsonb_build_object('reason', p_reason)
  );

  return v_booking;
end;
$$;

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

  if not (v_booking.commercial_ready and v_booking.operational_ready) then
    raise exception 'TM-003 cannot create lock before commercial and operational readiness';
  end if;

  select coalesce(max(version), 0) + 1 into v_next_version
  from public.tm003_booking_locks
  where booking_id = p_booking_id;

  insert into public.tm003_booking_locks(
    lock_id, booking_id, version, source_event_id, locked_by, snapshot, immutable
  ) values (
    'LCK-' || to_char(current_date, 'YYYYMMDD') || '-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,6)),
    p_booking_id, v_next_version, p_source_event_id, v_actor, p_snapshot, true
  ) returning * into v_lock;

  update public.tm003_bookings
  set latest_lock_id = v_lock.id,
      readiness_state = 'LOCKED'::tm003_readiness_state,
      status = case when status in ('CONFIRMED','GOVERNANCE_LOCKED') then 'GOVERNANCE_LOCKED'::tm003_booking_status else status end,
      updated_at = now()
  where id = p_booking_id;

  insert into public.tm003_audit_log(
    booking_id, actor_operator_id, action, new_data, metadata
  ) values (
    p_booking_id, v_actor, 'BOOKING_LOCK_CREATED',
    to_jsonb(v_lock),
    jsonb_build_object('version', v_next_version)
  );

  return v_lock;
end;
$$;

create or replace function public.tm003_request_change(
  p_booking_id uuid,
  p_summary text,
  p_proposed_patch jsonb,
  p_change_class tm003_change_class default null,
  p_signal_id uuid default null,
  p_requested_by uuid default null,
  p_approval_required boolean default true
)
returns public.tm003_change_requests
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id uuid;
  v_request public.tm003_change_requests%rowtype;
  v_actor uuid;
begin
  v_actor := coalesce(p_requested_by, public.tm003_current_operator_id());
  if v_actor is null then
    raise exception 'TM-003 change request requires an authenticated operator';
  end if;

  if not exists (select 1 from public.tm003_bookings where id = p_booking_id) then
    raise exception 'TM-003 booking not found: %', p_booking_id;
  end if;

  v_id := gen_random_uuid();

  insert into public.tm003_change_requests(
    id, change_request_id, booking_id, signal_id, requested_by,
    change_class, summary, proposed_patch, approval_required, approval_status
  ) values (
    v_id,
    'CR-' || to_char(current_date, 'YYYYMMDD') || '-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,6)),
    p_booking_id, p_signal_id, v_actor,
    p_change_class, p_summary, coalesce(p_proposed_patch, '{}'::jsonb),
    p_approval_required, case when p_approval_required then 'PENDING' else 'APPROVED' end
  ) returning * into v_request;

  insert into public.tm003_audit_log(
    booking_id, signal_id, actor_operator_id, action, new_data
  ) values (
    p_booking_id, p_signal_id, v_actor, 'CHANGE_REQUEST_CREATED', to_jsonb(v_request)
  );

  return v_request;
end;
$$;

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
  v_required tm003_role_code := 'manager';
  v_role tm003_role_code;
begin
  select * into v_request
  from public.tm003_change_requests
  where id = p_change_request_id
  for update;

  if not found then
    raise exception 'TM-003 change request not found: %', p_change_request_id;
  end if;

  v_actor := coalesce(p_actor_operator_id, public.tm003_current_operator_id());
  if v_actor is null then
    raise exception 'TM-003 approval requires an authenticated operator';
  end if;

  select role_code into v_role from public.tm003_operators where id = v_actor and is_active = true;
  if v_role is null or public.tm003_role_rank(v_role) > public.tm003_role_rank(v_required) then
    raise exception 'TM-003 material change approval requires manager authority';
  end if;

  update public.tm003_change_requests
  set approval_status = 'APPROVED',
      approved_by = v_actor,
      approved_at = now(),
      validation_result = jsonb_build_object('approved', true, 'resolution', p_resolution)
  where id = p_change_request_id
  returning * into v_request;

  insert into public.tm003_audit_log(
    booking_id, signal_id, actor_operator_id, action, new_data, metadata
  ) values (
    v_request.booking_id, v_request.signal_id, v_actor, 'CHANGE_REQUEST_APPROVED', to_jsonb(v_request),
    jsonb_build_object('resolution', p_resolution)
  );

  return v_request;
end;
$$;

revoke all on function public.tm003_transition_booking(uuid, tm003_booking_status, text, uuid) from public;
revoke all on function public.tm003_create_booking_lock(uuid, jsonb, uuid, uuid) from public;
revoke all on function public.tm003_request_change(uuid, text, jsonb, tm003_change_class, uuid, uuid, boolean) from public;
revoke all on function public.tm003_approve_change(uuid, uuid, text) from public;
