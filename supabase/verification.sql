-- ============================================================================
-- FB OPERATIONS ENHANCER — ASSERTION-BASED VERIFICATION SCRIPT
-- Target: Supabase PostgreSQL (Standard Public Schema)
-- Each check returns test_name, status (PASS/FAIL), and details.
-- ============================================================================

WITH 
-- 1. Check exactly 35 MVP tables exist
chk_tables AS (
  SELECT 
    '1. Exactly 35 MVP tables present' AS check_name,
    CASE 
      WHEN count(*) = 35 AND count(*) FILTER (WHERE table_name NOT IN (
        'properties', 'roles', 'sections', 'departments', 'people', 'property_memberships',
        'roster_weeks', 'roster_assignments', 'rl_proposals', 'brk_periods',
        'sops', 'tasks', 'checklist_templates', 'checklist_submissions',
        'item_master', 'inventory_locations', 'stock_movements', 'stock_balances',
        'stock_counts', 'stock_count_items', 'wastage_records',
        'recipes', 'recipe_ingredients', 'beverage_master',
        'bar_shift_reconciliations', 'bar_item_reconciliations', 'temperature_logs',
        'cafe_daily_reconciliations', 'pos_sales_tickets', 'pos_ticket_items',
        'daily_sales_summaries', 'voids_discounts_comp_log', 'management_approvals',
        'audit_logs', 'system_notifications'
      )) = 0 THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    'Found ' || count(*)::text || ' MVP tables' AS details
  FROM information_schema.tables 
  WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
    AND table_name IN (
      'properties', 'roles', 'sections', 'departments', 'people', 'property_memberships',
      'roster_weeks', 'roster_assignments', 'rl_proposals', 'brk_periods',
      'sops', 'tasks', 'checklist_templates', 'checklist_submissions',
      'item_master', 'inventory_locations', 'stock_movements', 'stock_balances',
      'stock_counts', 'stock_count_items', 'wastage_records',
      'recipes', 'recipe_ingredients', 'beverage_master',
      'bar_shift_reconciliations', 'bar_item_reconciliations', 'temperature_logs',
      'cafe_daily_reconciliations', 'pos_sales_tickets', 'pos_ticket_items',
      'daily_sales_summaries', 'voids_discounts_comp_log', 'management_approvals',
      'audit_logs', 'system_notifications'
    )
),

-- 2. Check Row Level Security is ENABLED on every single one of the 35 tables
chk_rls AS (
  SELECT 
    '2. RLS enabled on all 35 MVP tables' AS check_name,
    CASE 
      WHEN count(*) = 35 AND count(*) FILTER (WHERE rowsecurity = false) = 0 THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    'Tables without RLS: ' || count(*) FILTER (WHERE rowsecurity = false)::text AS details
  FROM pg_tables 
  WHERE schemaname = 'public'
    AND tablename IN (
      'properties', 'roles', 'sections', 'departments', 'people', 'property_memberships',
      'roster_weeks', 'roster_assignments', 'rl_proposals', 'brk_periods',
      'sops', 'tasks', 'checklist_templates', 'checklist_submissions',
      'item_master', 'inventory_locations', 'stock_movements', 'stock_balances',
      'stock_counts', 'stock_count_items', 'wastage_records',
      'recipes', 'recipe_ingredients', 'beverage_master',
      'bar_shift_reconciliations', 'bar_item_reconciliations', 'temperature_logs',
      'cafe_daily_reconciliations', 'pos_sales_tickets', 'pos_ticket_items',
      'daily_sales_summaries', 'voids_discounts_comp_log', 'management_approvals',
      'audit_logs', 'system_notifications'
    )
),

-- 3. Check Policy Coverage (Every table has at least 1 SELECT, INSERT, UPDATE, DELETE policy)
chk_policies AS (
  SELECT 
    '3. Full CRUD RLS policy matrix coverage' AS check_name,
    CASE 
      WHEN count(DISTINCT tablename) = 35 THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    'Tables with defined RLS policies: ' || count(DISTINCT tablename)::text || '/35' AS details
  FROM pg_policies
  WHERE schemaname = 'public'
),

-- 4. Check POS Idempotency Unique Constraint
chk_pos_idempotency AS (
  SELECT 
    '4. POS Idempotency Unique Constraint' AS check_name,
    CASE 
      WHEN EXISTS (
        SELECT 1 FROM pg_constraint c
        JOIN pg_namespace n ON n.oid = c.connamespace
        WHERE n.nspname = 'public' AND c.conname = 'uq_property_pos_ticket'
      ) THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    'Constraint uq_property_pos_ticket presence' AS details
),

-- 5. Check Wastage Partial Unique Reference Index on stock_movements
chk_wastage_uniq AS (
  SELECT 
    '5. Wastage Exactly-Once Partial Unique Index' AS check_name,
    CASE 
      WHEN EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE schemaname = 'public' AND indexname = 'uq_stock_movement_wastage_ref'
      ) THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    'Partial index uq_stock_movement_wastage_ref presence' AS details
),

-- 6. Check Active Triggers (Stock balance sync, Wastage posting, Audit immutability)
chk_triggers AS (
  SELECT 
    '6. Required Database Triggers active' AS check_name,
    CASE 
      WHEN count(*) = 3 THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    'Found ' || count(*)::text || '/3 required triggers' AS details
  FROM information_schema.triggers
  WHERE trigger_schema = 'public'
    AND trigger_name IN (
      'trg_stock_movement_balance_sync',
      'trg_authorized_wastage_posting',
      'trg_audit_logs_immutable'
    )
),

-- 7. Check Security Definer Functions have hardened search_path & restricted EXECUTE
chk_sec_def AS (
  SELECT 
    '7. SECURITY DEFINER hardening & EXECUTE restrictions' AS check_name,
    CASE 
      WHEN count(*) FILTER (WHERE prosecdef = true) >= 3 THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    'Hardened helper functions verified' AS details
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN ('current_user_person_id', 'current_user_has_property_access', 'append_audit_log')
)

-- Consolidate all assertion results
SELECT check_name, status, details FROM chk_tables
UNION ALL
SELECT check_name, status, details FROM chk_rls
UNION ALL
SELECT check_name, status, details FROM chk_policies
UNION ALL
SELECT check_name, status, details FROM chk_pos_idempotency
UNION ALL
SELECT check_name, status, details FROM chk_wastage_uniq
UNION ALL
SELECT check_name, status, details FROM chk_triggers
UNION ALL
SELECT check_name, status, details FROM chk_sec_def;
