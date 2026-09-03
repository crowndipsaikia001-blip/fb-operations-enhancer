-- TM-003 deterministic governance test scenarios v2
-- Disposable/local test database only. Entire fixture rolls back.

begin;

create temporary table tm003_test_context(
  property_id uuid,
  property_id_other uuid,
  admin_id uuid,
  manager_id uuid,
  supervisor_id uuid,
  staff_id uuid
) on commit drop;

insert into public.tm003_properties(name) values ('TM003 TEST PROPERTY') returning id into temporary?;
