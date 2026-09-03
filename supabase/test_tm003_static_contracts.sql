-- TM-003 V1 static contract tests.
-- No writes. These checks are safe to execute against a database once the migration
-- and mutation layer have been applied. They intentionally fail loudly when the
-- governed contract is absent.

DO $$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count
  FROM pg_type t
  JOIN pg_namespace n ON n.oid = t.typnamespace
  WHERE n.nspname = 'public'
    AND t.typname IN (
      'tm003_booking_status',
      'tm003_signal_type',
      'tm003_signal_class',
      'tm003_change_class',
      'tm003_authority_level',
      'tm003_readiness_state',
      'tm003_outcome_status',
      'tm003_role_code'
    );

  IF v_count <> 8 THEN
    RAISE EXCEPTION 'FAIL: expected 8 TM-003 enum types, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_name IN (
      'tm003_properties','tm003_operators','tm003_property_memberships',
      'tm003_bookings','tm003_signals','tm003_booking_events','tm003_booking_locks',
      'tm003_change_requests','tm003_tasks','tm003_escalations','tm003_outcomes',
      'tm003_audit_log'
    );

  IF v_count <> 12 THEN
    RAISE EXCEPTION 'FAIL: expected 12 TM-003 tables, found %', v_count;
  END IF;

  RAISE NOTICE 'PASS: required TM-003 types and tables exist';
END $$;

DO $$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'tm003_role_rank',
      'tm003_current_operator_id',
      'tm003_current_role_for_property',
      'tm003_has_property_access',
      'tm003_transition_booking',
      'tm003_create_booking_lock',
      'tm003_request_change',
      'tm003_approve_change',
      'tm003_apply_change'
    );

  IF v_count < 8 THEN
    RAISE EXCEPTION 'FAIL: expected core TM-003 governance functions, found %', v_count;
  END IF;

  RAISE NOTICE 'PASS: core TM-003 governance functions exist';
END $$;

DO $$
DECLARE
  v_bad integer;
BEGIN
  SELECT count(*) INTO v_bad
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname LIKE 'tm003_%'
    AND c.relkind = 'r'
    AND NOT c.relrowsecurity;

  IF v_bad <> 0 THEN
    RAISE EXCEPTION 'FAIL: % TM-003 tables do not have RLS enabled', v_bad;
  END IF;

  RAISE NOTICE 'PASS: all TM-003 tables have RLS enabled';
END $$;

DO $$
DECLARE
  v_bad integer;
BEGIN
  SELECT count(*) INTO v_bad
  FROM information_schema.triggers
  WHERE trigger_schema = 'public'
    AND trigger_name IN ('tm003_locks_immutable','tm003_signals_immutable','tm003_events_immutable')
    AND action_statement NOT ILIKE '%tm003_prevent_immutable_update%';

  IF v_bad <> 0 THEN
    RAISE EXCEPTION 'FAIL: immutable trigger contract mismatch';
  END IF;

  RAISE NOTICE 'PASS: immutable evidence/lock trigger contract';
END $$;

-- Role ordering is deterministic and must remain admin < manager < supervisor < staff.
SELECT
  tm003_role_rank('admin'::tm003_role_code)      AS admin_rank,
  tm003_role_rank('manager'::tm003_role_code)    AS manager_rank,
  tm003_role_rank('supervisor'::tm003_role_code) AS supervisor_rank,
  tm003_role_rank('staff'::tm003_role_code)      AS staff_rank;
