-- TM-003 V1 verification queries only. No writes.

-- 1. Required TM-003 tables.
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name like 'tm003_%'
order by table_name;

-- 2. Required TM-003 enum types.
select t.typname as type_name
from pg_type t
join pg_namespace n on n.oid = t.typnamespace
where n.nspname = 'public'
  and t.typname like 'tm003_%'
order by t.typname;

-- 3. Required TM-003 functions.
select p.proname as function_name,
       pg_get_function_identity_arguments(p.oid) as arguments
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname like 'tm003_%'
order by p.proname, arguments;

-- 4. RLS must be enabled for every TM-003 table.
select c.relname as table_name,
       c.relrowsecurity as rls_enabled,
       c.relforcerowsecurity as forced_rls
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname like 'tm003_%'
  and c.relkind = 'r'
order by c.relname;

-- 5. Immutable triggers must exist for evidence and locks.
select event_object_table as table_name,
       trigger_name
from information_schema.triggers
where trigger_schema = 'public'
  and trigger_name in (
    'tm003_locks_immutable',
    'tm003_signals_immutable',
    'tm003_events_immutable'
  )
order by event_object_table, trigger_name;

-- 6. Direct write-denial policies must exist.
select tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
  and policyname like 'tm003_%no_direct_write'
order by tablename, policyname;

-- 7. Validate the booking latest-lock FK.
select conname,
       conrelid::regclass as source_table,
       confrelid::regclass as target_table
from pg_constraint
where conname = 'tm003_bookings_latest_lock_fk';

-- 8. Role rank must produce admin < manager < supervisor < staff.
select
  tm003_role_rank('admin'::tm003_role_code) as admin_rank,
  tm003_role_rank('manager'::tm003_role_code) as manager_rank,
  tm003_role_rank('supervisor'::tm003_role_code) as supervisor_rank,
  tm003_role_rank('staff'::tm003_role_code) as staff_rank;
