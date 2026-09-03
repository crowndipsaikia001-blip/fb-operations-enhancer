-- TM-003 LOOP-BLR BD Booking Command System
-- Migration: 20260903000004_tm003_booking_command_v1
-- Scope: Booking intelligence, provenance, governance, locks, change control, audit.
-- Self-contained TM-003 schema; does not depend on legacy application tables.
-- No destructive operations.

create extension if not exists pgcrypto;

create type tm003_booking_status as enum (
  'ENQUIRY','TENTATIVE','AWAITING_INFORMATION','AWAITING_ADVANCE','CONFIRMED',
  'GOVERNANCE_LOCKED','PREPARING','READY','LIVE','CLOSING','COMPLETED',
  'CANCELLED','ON_HOLD','EXCEPTION'
);
create type tm003_signal_type as enum ('WHATSAPP','TELEGRAM','BD','CALL_NOTE','EMAIL','MANUAL','SYSTEM');
create type tm003_signal_class as enum (
  'NEW_BOOKING','BOOKING_CHANGE','HEADCOUNT_CHANGE','TIME_CHANGE','PAYMENT_UPDATE',
  'MENU_CHANGE','STOCK_CHANGE','ZONE_CHANGE','STAFF_CHANGE','DUTY_CHANGE','INCIDENT',
  'GUEST_REQUEST','DELAY','MANAGEMENT_INSTRUCTION','POLICY_SIGNAL','NON_OPERATIONAL_NOISE'
);
create type tm003_change_class as enum (
  'WITHIN_SCOPE','FLEXIBLE_ACCOMMODATION','COMMERCIAL_VARIATION',
  'OPERATIONAL_EXCEPTION','IMPOSSIBLE','BLOCKED'
);
create type tm003_authority_level as enum ('GREEN','AMBER','RED','BLACK');
create type tm003_readiness_state as enum ('NOT_READY','READY_FOR_LOCK','LOCKED','EXECUTION_READY','EXCEPTION');
create type tm003_outcome_status as enum ('SUCCESS','PARTIAL_SUCCESS','FAILED','CANCELLED');
create type tm003_role_code as enum ('admin','manager','supervisor','staff');

create table tm003_properties (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  timezone text not null default 'Asia/Kolkata',
  currency text not null default 'INR',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table tm003_operators (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  full_name text not null,
  email text,
  role_code tm003_role_code not null default 'staff',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table tm003_property_memberships (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references tm003_properties(id) on delete cascade,
  operator_id uuid not null references tm003_operators(id) on delete cascade,
  role_code tm003_role_code not null default 'staff',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(property_id, operator_id)
);

create or replace function tm003_role_rank(role_code tm003_role_code)
returns integer
language sql
immutable
as $$
  select case role_code
    when 'admin' then 1
    when 'manager' then 2
    when 'supervisor' then 3
    when 'staff' then 4
  end;
$$;

create or replace function tm003_current_operator_id()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select id
  from tm003_operators
  where auth_user_id = auth.uid() and is_active = true
  limit 1;
$$;

create or replace function tm003_current_role_for_property(target_property_id uuid)
returns tm003_role_code
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select pm.role_code
  from tm003_property_memberships pm
  join tm003_operators o on o.id = pm.operator_id
  where pm.property_id = target_property_id
    and pm.is_active = true
    and o.auth_user_id = auth.uid()
    and o.is_active = true
  order by tm003_role_rank(pm.role_code)
  limit 1;
$$;

create or replace function tm003_has_property_access(
  target_property_id uuid,
  required_role tm003_role_code default 'staff'
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    tm003_role_rank(tm003_current_role_for_property(target_property_id))
      <= tm003_role_rank(required_role),
    false
  );
$$;

create table tm003_bookings (
  id uuid primary key default gen_random_uuid(),
  booking_id text not null unique,
  property_id uuid not null references tm003_properties(id) on delete restrict,
  created_by uuid references tm003_operators(id) on delete set null,
  status tm003_booking_status not null default 'ENQUIRY',
  readiness_state tm003_readiness_state not null default 'NOT_READY',
  authority_level tm003_authority_level not null default 'GREEN',
  booking_date date,
  tentative_time timestamptz,
  guest_name text,
  guest_contact text,
  pax_planned integer check (pax_planned is null or pax_planned >= 0),
  pax_confirmed integer check (pax_confirmed is null or pax_confirmed >= 0),
  zone text,
  booking_mode text,
  package_name text,
  menu_name text,
  commercial_notes text,
  advance_required numeric(12,2),
  advance_received numeric(12,2),
  total_expected numeric(12,2),
  dietary_requirements jsonb not null default '[]'::jsonb,
  special_requests jsonb not null default '[]'::jsonb,
  staffing_notes jsonb not null default '[]'::jsonb,
  operational_notes jsonb not null default '[]'::jsonb,
  missing_information jsonb not null default '[]'::jsonb,
  conflicts jsonb not null default '[]'::jsonb,
  commercial_ready boolean not null default false,
  operational_ready boolean not null default false,
  execution_ready boolean not null default false,
  latest_lock_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index tm003_bookings_property_date_idx on tm003_bookings(property_id, booking_date);
create index tm003_bookings_status_idx on tm003_bookings(status);

create table tm003_signals (
  id uuid primary key default gen_random_uuid(),
  signal_id text not null unique,
  property_id uuid not null references tm003_properties(id) on delete restrict,
  booking_id uuid references tm003_bookings(id) on delete set null,
  duplicate_of_signal_id uuid references tm003_signals(id) on delete set null,
  source_type tm003_signal_type not null,
  source_name text,
  source_message_id text,
  source_timestamp timestamptz,
  ingested_at timestamptz not null default now(),
  raw_content text not null,
  attachment_reference text,
  signal_class tm003_signal_class,
  extraction_status text not null default 'PENDING',
  extraction_payload jsonb,
  confidence numeric(5,4) check (confidence is null or (confidence >= 0 and confidence <= 1)),
  created_at timestamptz not null default now()
);

create index tm003_signals_booking_idx on tm003_signals(booking_id, ingested_at desc);
create index tm003_signals_property_idx on tm003_signals(property_id, ingested_at desc);

create table tm003_booking_events (
  id uuid primary key default gen_random_uuid(),
  event_id text not null unique,
  booking_id uuid not null references tm003_bookings(id) on delete restrict,
  signal_id uuid references tm003_signals(id) on delete restrict,
  event_type text not null,
  actor_operator_id uuid references tm003_operators(id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index tm003_events_booking_idx on tm003_booking_events(booking_id, created_at desc);

create table tm003_booking_locks (
  id uuid primary key default gen_random_uuid(),
  lock_id text not null unique,
  booking_id uuid not null references tm003_bookings(id) on delete restrict,
  version integer not null check (version > 0),
  source_event_id uuid references tm003_booking_events(id) on delete restrict,
  locked_by uuid references tm003_operators(id) on delete set null,
  locked_at timestamptz not null default now(),
  snapshot jsonb not null,
  immutable boolean not null default true,
  unique(booking_id, version)
);

create table tm003_change_requests (
  id uuid primary key default gen_random_uuid(),
  change_request_id text not null unique,
  booking_id uuid not null references tm003_bookings(id) on delete restrict,
  signal_id uuid references tm003_signals(id) on delete restrict,
  requested_by uuid references tm003_operators(id) on delete set null,
  change_class tm003_change_class,
  summary text not null,
  proposed_patch jsonb not null default '{}'::jsonb,
  validation_result jsonb,
  approval_required boolean not null default true,
  approval_status text not null default 'PENDING',
  approved_by uuid references tm003_operators(id) on delete set null,
  approved_at timestamptz,
  applied_at timestamptz,
  created_at timestamptz not null default now()
);

create table tm003_tasks (
  id uuid primary key default gen_random_uuid(),
  task_id text not null unique,
  booking_id uuid not null references tm003_bookings(id) on delete restrict,
  title text not null,
  task_type text not null,
  owner_operator_id uuid references tm003_operators(id) on delete set null,
  due_at timestamptz,
  status text not null default 'OPEN',
  payload jsonb not null default '{}'::jsonb,
  completed_at timestamptz,
  completed_by uuid references tm003_operators(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table tm003_escalations (
  id uuid primary key default gen_random_uuid(),
  escalation_id text not null unique,
  booking_id uuid references tm003_bookings(id) on delete set null,
  signal_id uuid references tm003_signals(id) on delete set null,
  authority_level tm003_authority_level not null,
  reason text not null,
  status text not null default 'OPEN',
  assigned_operator_id uuid references tm003_operators(id) on delete set null,
  resolved_at timestamptz,
  resolution_notes text,
  created_at timestamptz not null default now()
);

create table tm003_outcomes (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references tm003_bookings(id) on delete restrict,
  outcome_status tm003_outcome_status not null,
  pax_actual integer check (pax_actual is null or pax_actual >= 0),
  revenue_actual numeric(12,2),
  upsell_revenue numeric(12,2),
  incidents jsonb not null default '[]'::jsonb,
  lessons jsonb not null default '[]'::jsonb,
  recorded_by uuid references tm003_operators(id) on delete set null,
  created_at timestamptz not null default now()
);

create table tm003_audit_log (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references tm003_bookings(id) on delete set null,
  signal_id uuid references tm003_signals(id) on delete set null,
  actor_operator_id uuid references tm003_operators(id) on delete set null,
  action text not null,
  previous_data jsonb,
  new_data jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table tm003_bookings
  add constraint tm003_bookings_latest_lock_fk
  foreign key (latest_lock_id) references tm003_booking_locks(id) on delete set null;

create or replace function tm003_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger tm003_properties_updated_at before update on tm003_properties
for each row execute function tm003_set_updated_at();
create trigger tm003_operators_updated_at before update on tm003_operators
for each row execute function tm003_set_updated_at();
create trigger tm003_bookings_updated_at before update on tm003_bookings
for each row execute function tm003_set_updated_at();
create trigger tm003_tasks_updated_at before update on tm003_tasks
for each row execute function tm003_set_updated_at();

create or replace function tm003_prevent_immutable_update()
returns trigger
language plpgsql
as $$
begin
  raise exception 'TM-003 record is immutable';
end;
$$;

create trigger tm003_locks_immutable before update or delete on tm003_booking_locks
for each row execute function tm003_prevent_immutable_update();
create trigger tm003_signals_immutable before update or delete on tm003_signals
for each row execute function tm003_prevent_immutable_update();
create trigger tm003_events_immutable before update or delete on tm003_booking_events
for each row execute function tm003_prevent_immutable_update();

alter table tm003_properties enable row level security;
alter table tm003_operators enable row level security;
alter table tm003_property_memberships enable row level security;
alter table tm003_bookings enable row level security;
alter table tm003_signals enable row level security;
alter table tm003_booking_events enable row level security;
alter table tm003_booking_locks enable row level security;
alter table tm003_change_requests enable row level security;
alter table tm003_tasks enable row level security;
alter table tm003_escalations enable row level security;
alter table tm003_outcomes enable row level security;
alter table tm003_audit_log enable row level security;

create policy tm003_properties_select on tm003_properties
  for select using (tm003_has_property_access(id, 'staff'));
create policy tm003_operators_self_select on tm003_operators
  for select using (id = tm003_current_operator_id());
create policy tm003_memberships_select on tm003_property_memberships
  for select using (tm003_has_property_access(property_id, 'staff'));
create policy tm003_bookings_select on tm003_bookings
  for select using (tm003_has_property_access(property_id, 'staff'));
create policy tm003_signals_select on tm003_signals
  for select using (tm003_has_property_access(property_id, 'staff'));
create policy tm003_events_select on tm003_booking_events
  for select using (exists (select 1 from tm003_bookings b where b.id = booking_id and tm003_has_property_access(b.property_id, 'staff')));
create policy tm003_locks_select on tm003_booking_locks
  for select using (exists (select 1 from tm003_bookings b where b.id = booking_id and tm003_has_property_access(b.property_id, 'staff')));
create policy tm003_change_requests_select on tm003_change_requests
  for select using (exists (select 1 from tm003_bookings b where b.id = booking_id and tm003_has_property_access(b.property_id, 'staff')));
create policy tm003_tasks_select on tm003_tasks
  for select using (exists (select 1 from tm003_bookings b where b.id = booking_id and tm003_has_property_access(b.property_id, 'staff')));
create policy tm003_escalations_select on tm003_escalations
  for select using (
    booking_id is null
    or exists (select 1 from tm003_bookings b where b.id = tm003_escalations.booking_id and tm003_has_property_access(b.property_id, 'staff'))
  );
create policy tm003_outcomes_select on tm003_outcomes
  for select using (exists (select 1 from tm003_bookings b where b.id = booking_id and tm003_has_property_access(b.property_id, 'staff')));
create policy tm003_audit_select on tm003_audit_log
  for select using (
    booking_id is null
    or exists (select 1 from tm003_bookings b where b.id = tm003_audit_log.booking_id and tm003_has_property_access(b.property_id, 'manager'))
  );

-- Direct authenticated clients have no generic write access.
-- Governed server-side operations use the service role and explicit application actions.
create policy tm003_properties_no_direct_write on tm003_properties for all using (false) with check (false);
create policy tm003_operators_no_direct_write on tm003_operators for all using (false) with check (false);
create policy tm003_memberships_no_direct_write on tm003_property_memberships for all using (false) with check (false);
create policy tm003_bookings_no_direct_write on tm003_bookings for all using (false) with check (false);
create policy tm003_signals_no_direct_write on tm003_signals for all using (false) with check (false);
create policy tm003_events_no_direct_write on tm003_booking_events for all using (false) with check (false);
create policy tm003_locks_no_direct_write on tm003_booking_locks for all using (false) with check (false);
create policy tm003_change_requests_no_direct_write on tm003_change_requests for all using (false) with check (false);
create policy tm003_tasks_no_direct_write on tm003_tasks for all using (false) with check (false);
create policy tm003_escalations_no_direct_write on tm003_escalations for all using (false) with check (false);
create policy tm003_outcomes_no_direct_write on tm003_outcomes for all using (false) with check (false);
create policy tm003_audit_no_direct_write on tm003_audit_log for all using (false) with check (false);

revoke all on function tm003_current_operator_id() from public;
revoke all on function tm003_current_role_for_property(uuid) from public;
revoke all on function tm003_has_property_access(uuid, tm003_role_code) from public;
grant execute on function tm003_current_operator_id() to authenticated;
grant execute on function tm003_current_role_for_property(uuid) to authenticated;
grant execute on function tm003_has_property_access(uuid, tm003_role_code) to authenticated;
