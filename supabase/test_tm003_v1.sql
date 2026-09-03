-- TM-003 deterministic governance test scenarios v2
-- Disposable/local test database only. Entire fixture rolls back.

begin;

create temporary table tm003_test_context(
  property_id uuid,
  property_id_other uuid,
  admin_id uuid,
  manager_id uuid,
  supervisor_id uuid,
  staff_id uuid,
  outsider_manager_id uuid
) on commit drop;

do $$
declare
  v_property uuid;
  v_other_property uuid;
  v_admin uuid;
  v_manager uuid;
  v_supervisor uuid;
  v_staff uuid;
  v_outsider_manager uuid;
begin
  insert into public.tm003_properties(name) values ('TM003 TEST PROPERTY') returning id into v_property;
  insert into public.tm003_properties(name) values ('TM003 OTHER PROPERTY') returning id into v_other_property;
  insert into public.tm003_operators(full_name, role_code) values ('TM003 Test Admin','admin') returning id into v_admin;
  insert into public.tm003_operators(full_name, role_code) values ('TM003 Test Manager','manager') returning id into v_manager;
  insert into public.tm003_operators(full_name, role_code) values ('TM003 Test Supervisor','supervisor') returning id into v_supervisor;
  insert into public.tm003_operators(full_name, role_code) values ('TM003 Test Staff','staff') returning id into v_staff;
  insert into public.tm003_operators(full_name, role_code) values ('TM003 Outsider Manager','manager') returning id into v_outsider_manager;
  insert into public.tm003_property_memberships(property_id, operator_id, role_code)
  values
    (v_property, v_admin, 'admin'),
    (v_property, v_manager, 'manager'),
    (v_property, v_supervisor, 'supervisor'),
    (v_property, v_staff, 'staff'),
    (v_other_property, v_outsider_manager, 'manager');
  insert into tm003_test_context(property_id, property_id_other, admin_id, manager_id, supervisor_id, staff_id, outsider_manager_id)
  values(v_property, v_other_property, v_admin, v_manager, v_supervisor, v_staff, v_outsider_manager);
end $$;

do $$ begin
  if public.tm003_role_rank('admin'::tm003_role_code) >= public.tm003_role_rank('manager'::tm003_role_code)
     or public.tm003_role_rank('manager'::tm003_role_code) >= public.tm003_role_rank('supervisor'::tm003_role_code)
     or public.tm003_role_rank('supervisor'::tm003_role_code) >= public.tm003_role_rank('staff'::tm003_role_code) then
    raise exception 'FAIL role hierarchy';
  end if;
end $$;

insert into public.tm003_bookings(
  booking_id, property_id, created_by, status, readiness_state,
  booking_date, guest_name, pax_planned, commercial_ready, operational_ready,
  advance_required, advance_received, total_expected
)
select 'BK-TEST-000001', property_id, admin_id, 'ENQUIRY', 'NOT_READY',
       current_date, 'TM003 Test Guest', 10, false, false, 1000, 1000, 10000
from tm003_test_context;

select public.tm003_transition_booking(
  (select id from public.tm003_bookings where booking_id='BK-TEST-000001'),
  'TENTATIVE', 'test transition', (select admin_id from tm003_test_context)
);

do $$ begin
  begin
    perform public.tm003_transition_booking(
      (select id from public.tm003_bookings where booking_id='BK-TEST-000001'),
      'LIVE', 'invalid jump', (select admin_id from tm003_test_context)
    );
    raise exception 'FAIL invalid lifecycle transition was accepted';
  exception when others then
    if position('invalid booking transition' in lower(sqlerrm)) = 0 then raise; end if;
  end;
end $$;

do $$ begin
  begin
    perform public.tm003_create_booking_lock(
      (select id from public.tm003_bookings where booking_id='BK-TEST-000001'),
      jsonb_build_object('test', true), null,
      (select admin_id from tm003_test_context)
    );
    raise exception 'FAIL lock accepted before governance lock';
  exception when others then
    if position('governance_locked' in lower(sqlerrm)) = 0 and position('ready_for_lock' in lower(sqlerrm)) = 0 then raise; end if;
  end;
end $$;

update public.tm003_bookings
set commercial_ready=true, operational_ready=true, readiness_state='READY_FOR_LOCK'
where booking_id='BK-TEST-000001';

select public.tm003_transition_booking(
  (select id from public.tm003_bookings where booking_id='BK-TEST-000001'),
  'GOVERNANCE_LOCKED', 'ready for lock', (select admin_id from tm003_test_context)
);

do $$ begin
  begin
    perform public.tm003_create_booking_lock(
      (select id from public.tm003_bookings where booking_id='BK-TEST-000001'),
      jsonb_build_object('booking_id','BK-TEST-000001','version',1), null,
      (select admin_id from tm003_test_context)
    );
    raise exception 'FAIL non-canonical lock snapshot accepted';
  exception when others then
    if position('snapshot' in lower(sqlerrm)) = 0 then raise; end if;
  end;
end $$;

select public.tm003_create_booking_lock(
  (select id from public.tm003_bookings where booking_id='BK-TEST-000001'),
  public.tm003_booking_snapshot((select id from public.tm003_bookings where booking_id='BK-TEST-000001')),
  null,
  (select admin_id from tm003_test_context)
);

do $$ begin
  if (select max(version) from public.tm003_booking_locks where booking_id=(select id from public.tm003_bookings where booking_id='BK-TEST-000001')) <> 1 then
    raise exception 'FAIL initial lock versioning';
  end if;
  if (select latest_lock_id from public.tm003_bookings where booking_id='BK-TEST-000001') is null then
    raise exception 'FAIL latest_lock_id not set';
  end if;
end $$;

select public.tm003_request_change(
  (select id from public.tm003_bookings where booking_id='BK-TEST-000001'),
  'Increase pax', jsonb_build_object('pax_confirmed',15),
  'COMMERCIAL_VARIATION', null,
  (select staff_id from tm003_test_context)
);

do $$ begin
  if (select approval_required from public.tm003_change_requests order by created_at desc limit 1) <> true
     or (select approval_status from public.tm003_change_requests order by created_at desc limit 1) <> 'PENDING' then
    raise exception 'FAIL change request approval gate';
  end if;
end $$;

do $$ begin
  begin
    perform public.tm003_approve_change(
      (select id from public.tm003_change_requests order by created_at desc limit 1),
      (select staff_id from tm003_test_context), 'unauthorized test'
    );
    raise exception 'FAIL staff approval accepted';
  exception when others then
    if position('requires manager authority in the booking property' in lower(sqlerrm)) = 0 then raise; end if;
  end;
end $$;

do $$ begin
  begin
    perform public.tm003_approve_change(
      (select id from public.tm003_change_requests order by created_at desc limit 1),
      (select outsider_manager_id from tm003_test_context), 'wrong property test'
    );
    raise exception 'FAIL wrong-property manager approval accepted';
  exception when others then
    if position('requires manager authority in the booking property' in lower(sqlerrm)) = 0 then raise; end if;
  end;
end $$;

select public.tm003_approve_change(
  (select id from public.tm003_change_requests order by created_at desc limit 1),
  (select manager_id from tm003_test_context), 'approved test'
);

do $$ begin
  begin
    perform public.tm003_approve_change(
      (select id from public.tm003_change_requests order by created_at desc limit 1),
      (select manager_id from tm003_test_context), 'duplicate approval test'
    );
    raise exception 'FAIL duplicate approval accepted';
  exception when others then
    if position('not pending approval' in lower(sqlerrm)) = 0 then raise; end if;
  end;
end $$;

-- Unsupported patch rejected; use current request row as a safe negative fixture.
do $$ begin
  update public.tm003_change_requests
  set proposed_patch=jsonb_build_object('arbitrary_field','bad')
  where id=(select id from public.tm003_change_requests order by created_at desc limit 1);
  begin
    perform public.tm003_apply_change(
      (select id from public.tm003_change_requests order by created_at desc limit 1),
      (select manager_id from tm003_test_context)
    );
    raise exception 'FAIL unsupported patch accepted';
  exception when others then
    if position('unsupported change fields' in lower(sqlerrm)) = 0 then raise; end if;
  end;
  update public.tm003_change_requests
  set proposed_patch=jsonb_build_object('pax_confirmed',15)
  where id=(select id from public.tm003_change_requests order by created_at desc limit 1);
end $$;

select public.tm003_apply_change(
  (select id from public.tm003_change_requests order by created_at desc limit 1),
  (select manager_id from tm003_test_context)
);

do $$ begin
  if (select pax_confirmed from public.tm003_bookings where booking_id='BK-TEST-000001') <> 15 then
    raise exception 'FAIL approved patch not applied';
  end if;
  if (select max(version) from public.tm003_booking_locks where booking_id=(select id from public.tm003_bookings where booking_id='BK-TEST-000001')) <> 2 then
    raise exception 'FAIL lock v2 not created';
  end if;
  if (select applied_at from public.tm003_change_requests order by created_at desc limit 1) is null then
    raise exception 'FAIL change request not marked applied';
  end if;
  if (select status from public.tm003_bookings where booking_id='BK-TEST-000001') <> 'GOVERNANCE_LOCKED' then
    raise exception 'FAIL booking not governance locked after applied change';
  end if;
  if (select readiness_state from public.tm003_bookings where booking_id='BK-TEST-000001') <> 'LOCKED' then
    raise exception 'FAIL booking not re-locked after applied change';
  end if;
end $$;

do $$ begin
  begin
    update public.tm003_booking_locks set snapshot='{"tampered":true}'::jsonb
    where booking_id=(select id from public.tm003_bookings where booking_id='BK-TEST-000001');
    raise exception 'FAIL immutable lock updated';
  exception when others then
    if position('immutable' in lower(sqlerrm)) = 0 then raise; end if;
  end;
end $$;

do $$ begin
  if not exists (
    select 1 from public.tm003_booking_events
    where booking_id=(select id from public.tm003_bookings where booking_id='BK-TEST-000001')
      and event_type='GOVERNED_CHANGE_APPLIED'
  ) then raise exception 'FAIL governed change event missing'; end if;
  if not exists (
    select 1 from public.tm003_audit_log
    where booking_id=(select id from public.tm003_bookings where booking_id='BK-TEST-000001')
      and action='CHANGE_APPLIED'
  ) then raise exception 'FAIL change audit missing'; end if;
end $$;

raise notice 'TM-003 HARD GATE PASSED: lifecycle -> lock v1 -> approval -> deterministic apply -> lock v2 -> audit';
rollback;
