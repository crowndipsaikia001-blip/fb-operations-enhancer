-- TM-003 deterministic governance test scenarios v1
-- These tests are READ/WRITE in a dedicated transaction and roll back at the end.
-- Run only against a disposable/local test database, not production.

begin;

-- Fixture property/operator setup. IDs are isolated through generated UUIDs.
insert into public.tm003_properties(name) values ('TM003 TEST PROPERTY') returning id;

create temporary table tm003_test_context(
  property_id uuid,
  admin_id uuid,
  supervisor_id uuid,
  staff_id uuid
) on commit drop;

with p as (
  select id from public.tm003_properties where name = 'TM003 TEST PROPERTY' order by created_at desc limit 1
), ins as (
  insert into public.tm003_operators(full_name, role_code)
  values ('TM003 Test Admin','admin'),('TM003 Test Supervisor','supervisor'),('TM003 Test Staff','staff')
  returning id, role_code
)
insert into tm003_test_context(property_id, admin_id, supervisor_id, staff_id)
select p.id,
       max(ins.id) filter (where ins.role_code='admin'),
       max(ins.id) filter (where ins.role_code='supervisor'),
       max(ins.id) filter (where ins.role_code='staff')
from p cross join ins
on conflict do nothing;

insert into public.tm003_property_memberships(property_id, operator_id, role_code)
select property_id, admin_id, 'admin' from tm003_test_context
union all
select property_id, supervisor_id, 'supervisor' from tm003_test_context
union all
select property_id, staff_id, 'staff' from tm003_test_context;

-- Role hierarchy.
do $$ begin
  if public.tm003_role_rank('admin'::tm003_role_code) >= public.tm003_role_rank('manager'::tm003_role_code)
     or public.tm003_role_rank('manager'::tm003_role_code) >= public.tm003_role_rank('supervisor'::tm003_role_code)
     or public.tm003_role_rank('supervisor'::tm003_role_code) >= public.tm003_role_rank('staff'::tm003_role_code) then
    raise exception 'FAIL role hierarchy';
  end if;
end $$;

-- Booking fixture.
insert into public.tm003_bookings(
  booking_id, property_id, created_by, status, readiness_state,
  booking_date, guest_name, pax_planned, commercial_ready, operational_ready
)
select 'BK-TEST-000001', property_id, admin_id, 'ENQUIRY', 'NOT_READY',
       current_date, 'TM003 Test Guest', 10, false, false
from tm003_test_context;

-- Valid ENQUIRY -> TENTATIVE.
select public.tm003_transition_booking(
  (select id from public.tm003_bookings where booking_id='BK-TEST-000001'),
  'TENTATIVE', 'test transition', (select admin_id from tm003_test_context)
);

-- Invalid TENTATIVE -> LIVE must fail.
do $$ begin
  begin
    perform public.tm003_transition_booking(
      (select id from public.tm003_bookings where booking_id='BK-TEST-000001'),
      'LIVE', 'invalid jump', (select admin_id from tm003_test_context)
    );
    raise exception 'FAIL invalid lifecycle transition was accepted';
  exception when others then
    if position('invalid booking transition' in sqlerrm) = 0 then
      raise;
    end if;
  end;
end $$;

-- Cannot lock until readiness is satisfied.
do $$ begin
  begin
    perform public.tm003_create_booking_lock(
      (select id from public.tm003_bookings where booking_id='BK-TEST-000001'),
      jsonb_build_object('test', true),
      null,
      (select admin_id from tm003_test_context)
    );
    raise exception 'FAIL lock accepted without readiness';
  exception when others then
    if position('not ready for governance lock' in lower(sqlerrm)) = 0 then
      raise;
    end if;
  end;
end $$;

update public.tm003_bookings
set commercial_ready=true,
    operational_ready=true,
    readiness_state='READY_FOR_LOCK'
where booking_id='BK-TEST-000001';

select public.tm003_transition_booking(
  (select id from public.tm003_bookings where booking_id='BK-TEST-000001'),
  'GOVERNANCE_LOCKED', 'ready for lock', (select admin_id from tm003_test_context)
);

select public.tm003_create_booking_lock(
  (select id from public.tm003_bookings where booking_id='BK-TEST-000001'),
  jsonb_build_object('booking_id','BK-TEST-000001','version',1),
  null,
  (select admin_id from tm003_test_context)
);

-- Second lock must version to 2.
select public.tm003_create_booking_lock(
  (select id from public.tm003_bookings where booking_id='BK-TEST-000001'),
  jsonb_build_object('booking_id','BK-TEST-000001','version',2),
  null,
  (select admin_id from tm003_test_context)
);

do $$ begin
  if (select max(version) from public.tm003_booking_locks where booking_id=(select id from public.tm003_bookings where booking_id='BK-TEST-000001')) <> 2 then
    raise exception 'FAIL lock versioning';
  end if;
end $$;

-- Change request approval boundary.
select public.tm003_request_change(
  (select id from public.tm003_bookings where booking_id='BK-TEST-000001'),
  'Increase pax',
  jsonb_build_object('pax_confirmed',15),
  'COMMERCIAL_VARIATION',
  null,
  (select staff_id from tm003_test_context),
  true
);

-- Staff cannot approve material change.
do $$ begin
  begin
    perform public.tm003_approve_change(
      (select id from public.tm003_change_requests order by created_at desc limit 1),
      (select staff_id from tm003_test_context),
      'unauthorized test'
    );
    raise exception 'FAIL staff approval accepted';
  exception when others then
    if position('requires manager authority' in lower(sqlerrm)) = 0 then
      raise;
    end if;
  end;
end $$;

-- Manager/admin authority can approve. Admin is intentionally valid for this v1 baseline.
select public.tm003_approve_change(
  (select id from public.tm003_change_requests order by created_at desc limit 1),
  (select admin_id from tm003_test_context),
  'approved test'
);

-- Immutable lock/signal/event guards.
do $$ begin
  begin
    update public.tm003_booking_locks set snapshot='{"tampered":true}'::jsonb
    where booking_id=(select id from public.tm003_bookings where booking_id='BK-TEST-000001');
    raise exception 'FAIL immutable lock updated';
  exception when others then
    if position('immutable' in lower(sqlerrm)) = 0 then raise; end if;
  end;
end $$;

raise notice 'TM-003 governance tests passed';
rollback;
