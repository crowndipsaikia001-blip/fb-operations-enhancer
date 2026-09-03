-- TM-003 Governance Enforcement V1
-- Converts the reviewed foundation into a deterministic, server-governed mutation path.
-- No autonomous approvals. No direct client writes. All material changes require approval.

create or replace function public.tm003_booking_snapshot(p_booking_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_booking public.tm003_bookings%rowtype;
begin
  select * into v_booking from public.tm003_bookings where id = p_booking_id;
  if not found then
    raise exception 'TM-003 booking not found: %', p_booking_id;
  end if;
  return jsonb_build_object(
    'id', v_booking.id,
    'booking_id', v_booking.booking_id,
    'property_id', v_booking.property_id,
    'guest_name', v_booking.guest_name,
    'guest_contact', v_booking.guest_contact,
    'booking_date', v_booking.booking_date,
    'tentative_time', v_booking.tentative_time,
    'pax_planned', v_booking.pax_planned,
    'pax_confirmed', v_booking.pax_confirmed,
    'booking_mode', v_booking.booking_mode,
    'zone', v_booking.zone,
    'package_name', v_booking.package_name,
    'menu_name', v_booking.menu_name,
    'commercial_notes', v_booking.commercial_notes,
    'dietary_requirements', v_booking.dietary_requirements,
    'special_requests', v_booking.special_requests,
    'staffing_notes', v_booking.staffing_notes,
    'operational_notes', v_booking.operational_notes,
    'advance_required', v_booking.advance_required,
    'advance_received', v_booking.advance_received,
    'total_expected', v_booking.total_expected,
    'commercial_ready', v_booking.commercial_ready,
    'operational_ready', v_booking.operational_ready,
    'execution_ready', v_booking.execution_ready,
    'readiness_state', v_booking.readiness_state,
    'status', v_booking.status,
    'authority_level', v_booking.authority_level
  );
end;
$$;

-- Fix status-transition audit provenance and lock semantics.
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
  v_before public.tm003_bookings%rowtype;
  v_after public.tm003_bookings%rowtype;
  v_actor uuid;
  v_allowed boolean := false;
begin
  select * into v_before from public.tm003_bookings where id = p_booking_id for update;
  if not found then raise exception 'TM-003 booking not found: %', p_booking_id; end if;

  v_actor := coalesce(p_actor_operator_id, public.tm003_current_operator_id());
  if v_actor is null then raise exception 'TM-003 transition requires an authenticated operator'; end if;

  if v_before.status = p_to_status then return v_before; end if;

  v_allowed := case v_before.status
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

  if not v_allowed then raise exception 'TM-003 invalid booking transition: % -> %', v_before.status, p_to_status; end if;

  if p_to_status = 'GOVERNANCE_LOCKED' and not (
    v_before.commercial_ready and v_before.operational_ready and v_before.readiness_state = 'READY_FOR_LOCK'
  ) then
    raise exception 'TM-003 booking is not ready for governance lock';
  end if;

  update public.tm003_bookings
  set status = p_to_status,
      readiness_state = case
        when p_to_status in ('ON_HOLD','EXCEPTION') then 'EXCEPTION'::tm003_readiness_state
        when p_to_status = 'GOVERNANCE_LOCKED' then 'READY_FOR_LOCK'::tm003_readiness_state
        when p_to_status in ('READY','LIVE') and execution_ready then 'EXECUTION_READY'::tm003_readiness_state
        else readiness_state
      end,
      updated_at = now()
  where id = p_booking_id
  returning * into v_after;

  insert into public.tm003_audit_log(booking_id, actor_operator_id, action, previous_data, new_data, metadata)
  values(
    p_booking_id, v_actor, 'BOOKING_STATUS_TRANSITION',
    jsonb_build_object('status', v_before.status),
    jsonb_build_object('status', v_after.status),
    jsonb_build_object('reason', p_reason)
  );
  return v_after;
end;
$$;

-- Change requests are always approval-gated in V1. No caller-controlled bypass flag.
drop function if exists public.tm003_request_change(uuid, text, jsonb, tm003_change_class, uuid, uuid, boolean);
create or replace function public.tm003_request_change(
  p_booking_id uuid,
  p_summary text,
  p_proposed_patch jsonb,
  p_change_class tm003_change_class default null,
  p_signal_id uuid default null,
  p_requested_by uuid default null
)
returns public.tm003_change_requests
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id uuid := gen_random_uuid();
  v_actor uuid;
  v_request public.tm003_change_requests%rowtype;
begin
  v_actor := coalesce(p_requested_by, public.tm003_current_operator_id());
  if v_actor is null then raise exception 'TM-003 change request requires an authenticated operator'; end if;
  if not exists(select 1 from public.tm003_bookings where id = p_booking_id) then raise exception 'TM-003 booking not found: %', p_booking_id; end if;

  insert into public.tm003_change_requests(
    id, change_request_id, booking_id, signal_id, requested_by,
    change_class, summary, proposed_patch, approval_required, approval_status
  ) values(
    v_id,
    'CR-' || to_char(current_date,'YYYYMMDD') || '-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,6)),
    p_booking_id, p_signal_id, v_actor,
    p_change_class, p_summary, coalesce(p_proposed_patch,'{}'::jsonb), true, 'PENDING'
  ) returning * into v_request;

  insert into public.tm003_audit_log(booking_id, signal_id, actor_operator_id, action, new_data)
  values(p_booking_id, p_signal_id, v_actor, 'CHANGE_REQUEST_CREATED', to_jsonb(v_request));
  return v_request;
end;
$$;

-- Property-scoped manager/admin approval only.
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
  v_property uuid;
begin
  select * into v_request from public.tm003_change_requests where id = p_change_request_id for update;
  if not found then raise exception 'TM-003 change request not found: %', p_change_request_id; end if;
  if v_request.approval_status <> 'PENDING' then raise exception 'TM-003 change request is not pending approval'; end if;

  v_actor := coalesce(p_actor_operator_id, public.tm003_current_operator_id());
  if v_actor is null then raise exception 'TM-003 approval requires an authenticated operator'; end if;

  select property_id into v_property from public.tm003_bookings where id = v_request.booking_id;
  select pm.role_code into v_role
  from public.tm003_property_memberships pm
  where pm.property_id = v_property and pm.operator_id = v_actor and pm.is_active = true;
  if v_role is null or public.tm003_role_rank(v_role) > public.tm003_role_rank('manager'::tm003_role_code) then
    raise exception 'TM-003 material change approval requires manager authority in the booking property';
  end if;

  update public.tm003_change_requests
  set approval_status='APPROVED', approved_by=v_actor, approved_at=now(),
      validation_result=jsonb_build_object('approved',true,'resolution',p_resolution,'validated_at',now())
  where id=p_change_request_id returning * into v_request;

  insert into public.tm003_audit_log(booking_id, signal_id, actor_operator_id, action, new_data, metadata)
  values(v_request.booking_id,v_request.signal_id,v_actor,'CHANGE_REQUEST_APPROVED',to_jsonb(v_request),jsonb_build_object('resolution',p_resolution));
  return v_request;
end;
$$;

-- Deterministic patch application. V1 intentionally whitelists mutable booking fields.
create or replace function public.tm003_apply_change(
  p_change_request_id uuid,
  p_actor_operator_id uuid default null
)
returns public.tm003_bookings
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_request public.tm003_change_requests%rowtype;
  v_before public.tm003_bookings%rowtype;
  v_after public.tm003_bookings%rowtype;
  v_actor uuid;
  v_patch jsonb;
  v_key text;
  v_unknown text[] := '{}';
  v_new_lock public.tm003_booking_locks%rowtype;
  v_snapshot jsonb;
begin
  select * into v_request from public.tm003_change_requests where id=p_change_request_id for update;
  if not found then raise exception 'TM-003 change request not found: %', p_change_request_id; end if;
  if v_request.approval_status <> 'APPROVED' then raise exception 'TM-003 change request must be approved before application'; end if;
  if v_request.change_class in ('IMPOSSIBLE','BLOCKED') then raise exception 'TM-003 change class % cannot be applied', v_request.change_class; end if;

  v_actor := coalesce(p_actor_operator_id, public.tm003_current_operator_id());
  if v_actor is null then raise exception 'TM-003 apply requires an authenticated operator'; end if;

  select * into v_before from public.tm003_bookings where id=v_request.booking_id for update;
  if not found then raise exception 'TM-003 booking not found: %', v_request.booking_id; end if;
  if v_before.status <> 'GOVERNANCE_LOCKED' or v_before.latest_lock_id is null then
    raise exception 'TM-003 approved change application requires an existing governance lock';
  end if;

  v_patch := coalesce(v_request.proposed_patch,'{}'::jsonb);
  for v_key in select jsonb_object_keys(v_patch) loop
    if v_key not in (
      'guest_name','guest_contact','booking_date','tentative_time','pax_planned','pax_confirmed',
      'booking_mode','zone','package_name','menu_name','commercial_notes','dietary_requirements',
      'special_requests','staffing_notes','operational_notes','advance_required','advance_received','total_expected'
    ) then
      v_unknown := array_append(v_unknown,v_key);
    end if;
  end loop;
  if cardinality(v_unknown) > 0 then raise exception 'TM-003 unsupported change fields: %', v_unknown; end if;

  update public.tm003_bookings
  set guest_name=coalesce(v_patch->>'guest_name',guest_name),
      guest_contact=coalesce(v_patch->>'guest_contact',guest_contact),
      booking_date=coalesce((v_patch->>'booking_date')::date,booking_date),
      tentative_time=coalesce(v_patch->>'tentative_time',tentative_time),
      pax_planned=coalesce((v_patch->>'pax_planned')::integer,pax_planned),
      pax_confirmed=coalesce((v_patch->>'pax_confirmed')::integer,pax_confirmed),
      booking_mode=coalesce(v_patch->>'booking_mode',booking_mode),
      zone=coalesce(v_patch->>'zone',zone),
      package_name=coalesce(v_patch->>'package_name',package_name),
      menu_name=coalesce(v_patch->>'menu_name',menu_name),
      commercial_notes=coalesce(v_patch->>'commercial_notes',commercial_notes),
      dietary_requirements=coalesce(v_patch->>'dietary_requirements',dietary_requirements),
      special_requests=coalesce(v_patch->>'special_requests',special_requests),
      staffing_notes=coalesce(v_patch->>'staffing_notes',staffing_notes),
      operational_notes=coalesce(v_patch->>'operational_notes',operational_notes),
      advance_required=coalesce((v_patch->>'advance_required')::numeric,advance_required),
      advance_received=coalesce((v_patch->>'advance_received')::numeric,advance_received),
      total_expected=coalesce((v_patch->>'total_expected')::numeric,total_expected),
      updated_at=now(),
      readiness_state='READY_FOR_LOCK'::tm003_readiness_state
  where id=v_request.booking_id
  returning * into v_after;

  if v_after.pax_planned is not null and v_after.pax_planned < 0 then raise exception 'TM-003 pax_planned cannot be negative'; end if;
  if v_after.pax_confirmed is not null and v_after.pax_confirmed < 0 then raise exception 'TM-003 pax_confirmed cannot be negative'; end if;
  if v_after.advance_required is not null and v_after.advance_required < 0 then raise exception 'TM-003 advance_required cannot be negative'; end if;
  if v_after.advance_received is not null and v_after.advance_received < 0 then raise exception 'TM-003 advance_received cannot be negative'; end if;
  if v_after.total_expected is not null and v_after.total_expected < 0 then raise exception 'TM-003 total_expected cannot be negative'; end if;

  insert into public.tm003_booking_events(event_id,booking_id,signal_id,event_type,actor_operator_id,payload)
  values(
    'EVT-' || to_char(current_date,'YYYYMMDD') || '-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,6)),
    v_after.id,v_request.signal_id,'GOVERNED_CHANGE_APPLIED',v_actor,
    jsonb_build_object('change_request_id',v_request.id,'change_request_key',v_request.change_request_id,'patch',v_patch)
  );

  v_snapshot := public.tm003_booking_snapshot(v_after.id);

  perform set_config('tm003.internal_apply','on',true);
  select * into v_new_lock
  from public.tm003_create_booking_lock(
    v_after.id, v_snapshot, null, v_actor
  );

  update public.tm003_change_requests
  set applied_at=now(), approval_status='APPROVED', validation_result=jsonb_build_object('applied',true,'lock_version',v_new_lock.version)
  where id=v_request.id;

  insert into public.tm003_audit_log(booking_id,signal_id,actor_operator_id,action,previous_data,new_data,metadata)
  values(
    v_after.id,v_request.signal_id,v_actor,'CHANGE_APPLIED',
    public.tm003_booking_snapshot(v_before),
    v_snapshot,
    jsonb_build_object('change_request_id',v_request.id,'lock_version',v_new_lock.version)
  );

  return (select b.* from public.tm003_bookings b where b.id=v_after.id);
end;
$$;

-- Lock creation validates the supplied snapshot against the canonical current booking state.
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
  v_expected_snapshot jsonb;
begin
  select * into v_booking from public.tm003_bookings where id=p_booking_id for update;
  if not found then raise exception 'TM-003 booking not found: %', p_booking_id; end if;
  v_actor := coalesce(p_actor_operator_id,public.tm003_current_operator_id());
  if v_actor is null then raise exception 'TM-003 lock creation requires an authenticated operator'; end if;
  if v_booking.status <> 'GOVERNANCE_LOCKED' then raise exception 'TM-003 booking must be GOVERNANCE_LOCKED before lock creation'; end if;
  if v_booking.readiness_state <> 'READY_FOR_LOCK' then raise exception 'TM-003 booking must have READY_FOR_LOCK readiness before lock creation'; end if;
  if not(v_booking.commercial_ready and v_booking.operational_ready) then raise exception 'TM-003 cannot create lock before commercial and operational readiness'; end if;

  v_expected_snapshot := public.tm003_booking_snapshot(p_booking_id);
  if coalesce(p_snapshot,'{}'::jsonb) <> v_expected_snapshot then raise exception 'TM-003 supplied lock snapshot does not match canonical booking state'; end if;

  select coalesce(max(version),0)+1 into v_next_version from public.tm003_booking_locks where booking_id=p_booking_id;
  if v_next_version > 1 and v_booking.latest_lock_id is null then raise exception 'TM-003 lock chain is inconsistent: missing latest lock'; end if;

  if p_source_event_id is not null and not exists(select 1 from public.tm003_booking_events e where e.id=p_source_event_id and e.booking_id=p_booking_id) then
    raise exception 'TM-003 source event does not belong to booking';
  end if;

  insert into public.tm003_booking_locks(lock_id,booking_id,version,source_event_id,locked_by,snapshot,immutable)
  values('LCK-'||to_char(current_date,'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,6)),p_booking_id,v_next_version,p_source_event_id,v_actor,v_expected_snapshot,true)
  returning * into v_lock;

  update public.tm003_bookings set latest_lock_id=v_lock.id,readiness_state='LOCKED'::tm003_readiness_state,updated_at=now() where id=p_booking_id;
  insert into public.tm003_audit_log(booking_id,actor_operator_id,action,new_data,metadata)
  values(p_booking_id,v_actor,'BOOKING_LOCK_CREATED',to_jsonb(v_lock),jsonb_build_object('version',v_next_version));
  return v_lock;
end;
$$;

-- Immutable audit log.
create or replace function public.tm003_prevent_audit_mutation()
returns trigger language plpgsql as $$
begin
  raise exception 'TM-003 audit log is append-only';
end;
$$;
drop trigger if exists tm003_audit_immutable on public.tm003_audit_log;
create trigger tm003_audit_immutable before update or delete on public.tm003_audit_log for each row execute function public.tm003_prevent_audit_mutation();

-- Prevent booking mutation through direct clients. Server-side governed functions remain the mutation path.
revoke all on function public.tm003_booking_snapshot(uuid) from public, anon;
grant execute on function public.tm003_booking_snapshot(uuid) to authenticated, service_role;
revoke all on function public.tm003_transition_booking(uuid,tm003_booking_status,text,uuid) from public,anon,authenticated;
revoke all on function public.tm003_create_booking_lock(uuid,jsonb,uuid,uuid) from public,anon,authenticated;
revoke all on function public.tm003_request_change(uuid,text,jsonb,tm003_change_class,uuid,uuid) from public,anon,authenticated;
revoke all on function public.tm003_approve_change(uuid,uuid,text) from public,anon,authenticated;
revoke all on function public.tm003_apply_change(uuid,uuid) from public,anon,authenticated;
grant execute on function public.tm003_transition_booking(uuid,tm003_booking_status,text,uuid) to service_role;
grant execute on function public.tm003_create_booking_lock(uuid,jsonb,uuid,uuid) to service_role;
grant execute on function public.tm003_request_change(uuid,text,jsonb,tm003_change_class,uuid,uuid) to service_role;
grant execute on function public.tm003_approve_change(uuid,uuid,text) to service_role;
grant execute on function public.tm003_apply_change(uuid,uuid) to service_role;

-- Replace stale static-contract expectations with the actual V1 signature set.
