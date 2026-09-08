-- TM-003 focused regression: JSON patches must preserve native booking column types.
begin;
create temporary table tm003_test_ids(actor_id uuid, property_id uuid, booking_id uuid, change_id uuid) on commit drop;
do $$
declare
  v_property uuid;
  v_actor uuid;
  v_booking uuid;
  v_change uuid;
begin
  insert into public.tm003_properties(name) values ('TM003 TYPE TEST') returning id into v_property;
  insert into public.tm003_operators(full_name, role_code) values ('TM003 Type Test Admin','admin') returning id into v_actor;
  insert into public.tm003_property_memberships(property_id, operator_id, role_code) values (v_property,v_actor,'admin');
  insert into public.tm003_bookings(
    booking_id, property_id, created_by, status, readiness_state, booking_date,
    guest_name, pax_planned, commercial_ready, operational_ready,
    advance_required, advance_received, total_expected
  ) values (
    'BK-TYPE-000001', v_property, v_actor, 'ENQUIRY', 'NOT_READY', current_date,
    'Type Test Guest', 10, false, false, 1000, 1000, 10000
  ) returning id into v_booking;
  insert into tm003_test_ids values(v_actor,v_property,v_booking,null);
end $$;
select set_config('tm003.actor_operator_id',(select actor_id::text from tm003_test_ids),false);
update public.tm003_bookings set commercial_ready=true, operational_ready=true, readiness_state='READY_FOR_LOCK' where id=(select booking_id from tm003_test_ids);
select public.tm003_transition_booking((select booking_id from tm003_test_ids),'TENTATIVE','type test');
select public.tm003_transition_booking((select booking_id from tm003_test_ids),'CONFIRMED','type test');
select public.tm003_transition_booking((select booking_id from tm003_test_ids),'GOVERNANCE_LOCKED','type test');
select public.tm003_create_booking_lock((select booking_id from tm003_test_ids),public.tm003_booking_snapshot((select booking_id from tm003_test_ids)),null);
select public.tm003_request_change((select booking_id from tm003_test_ids),'timestamp patch',jsonb_build_object('tentative_time','2030-01-02T19:30:00+05:30'),'WITHIN_SCOPE');
select public.tm003_approve_change((select id from public.tm003_change_requests order by created_at desc limit 1),null,'type test approval');
select public.tm003_apply_change((select id from public.tm003_change_requests order by created_at desc limit 1));
do $$
declare v_t timestamptz;
begin
  select tentative_time into v_t from public.tm003_bookings where id=(select booking_id from tm003_test_ids);
  if v_t <> '2030-01-02T19:30:00+05:30'::timestamptz then
    raise exception 'FAIL tentative_time patch type handling: %', v_t;
  end if;
end $$;
raise notice 'TM-003 TYPE REGRESSION PASSED';
rollback;
