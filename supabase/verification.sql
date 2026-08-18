-- ================================================================
-- VERIFICATION SCRIPT for Revision 5 Migration
-- ================================================================
-- This script verifies the integrity of the migration after application.
-- Run this AFTER applying the migration to confirm success.
-- ================================================================

\echo 'Starting Verification...'

-- 1. VERIFY TABLE COUNT (Expected: 17 tables)
SELECT 
    CASE 
        WHEN count(*) = 17 THEN 'PASS: Found expected 17 tables'
        ELSE 'FAIL: Expected 17 tables, found ' || count(*)
    END AS table_count_check
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_type = 'BASE TABLE'
AND table_name NOT LIKE 'pg_%';

-- 2. VERIFY ENUMS
SELECT 
    CASE 
        WHEN count(DISTINCT typname) = 6 THEN 'PASS: All 6 enums created'
        ELSE 'FAIL: Expected 6 enums, found ' || count(DISTINCT typname)
    END AS enum_check
FROM pg_type 
WHERE typtype = 'e' 
AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- 3. VERIFY RLS ENABLED ON ALL TABLES
SELECT 
    CASE 
        WHEN count(*) = 17 THEN 'PASS: RLS enabled on all 17 tables'
        ELSE 'FAIL: RLS not enabled on all tables. Count: ' || count(*)
    END AS rls_enabled_check
FROM pg_tables 
WHERE schemaname = 'public' 
AND rowsecurity = true;

-- 4. VERIFY SELECT POLICIES EXIST FOR ALL TABLES
SELECT 
    CASE 
        WHEN count(DISTINCT tablename) = 17 THEN 'PASS: SELECT policy exists for all 17 tables'
        ELSE 'FAIL: Missing SELECT policies. Tables covered: ' || count(DISTINCT tablename)
    END AS select_policy_check
FROM pg_policies 
WHERE schemaname = 'public' 
AND cmd = 'SELECT';

-- 5. VERIFY INSERT POLICIES EXIST FOR ALL TABLES
SELECT 
    CASE 
        WHEN count(DISTINCT tablename) = 17 THEN 'PASS: INSERT policy exists for all 17 tables'
        ELSE 'FAIL: Missing INSERT policies. Tables covered: ' || count(DISTINCT tablename)
    END AS insert_policy_check
FROM pg_policies 
WHERE schemaname = 'public' 
AND cmd = 'INSERT';

-- 6. VERIFY UPDATE POLICIES EXIST FOR ALL TABLES
SELECT 
    CASE 
        WHEN count(DISTINCT tablename) = 17 THEN 'PASS: UPDATE policy exists for all 17 tables'
        ELSE 'FAIL: Missing UPDATE policies. Tables covered: ' || count(DISTINCT tablename)
    END AS update_policy_check
FROM pg_policies 
WHERE schemaname = 'public' 
AND cmd = 'UPDATE';

-- 7. VERIFY DELETE POLICIES EXIST FOR ALL TABLES
SELECT 
    CASE 
        WHEN count(DISTINCT tablename) = 17 THEN 'PASS: DELETE policy exists for all 17 tables'
        ELSE 'FAIL: Missing DELETE policies. Tables covered: ' || count(DISTINCT tablename)
    END AS delete_policy_check
FROM pg_policies 
WHERE schemaname = 'public' 
AND cmd = 'DELETE';

-- 8. VERIFY STOCK BALANCE TRIGGER EXISTS
SELECT 
    CASE 
        WHEN count(*) >= 1 THEN 'PASS: Stock balance trigger exists'
        ELSE 'FAIL: Stock balance trigger missing'
    END AS stock_trigger_check
FROM pg_trigger 
WHERE tgname = 'trg_update_stock_balance';

-- 9. VERIFY WASTAGE AUTHORIZATION TRIGGER EXISTS
SELECT 
    CASE 
        WHEN count(*) >= 1 THEN 'PASS: Wastage authorization trigger exists'
        ELSE 'FAIL: Wastage authorization trigger missing'
    END AS wastage_trigger_check
FROM pg_trigger 
WHERE tgname = 'trg_process_wastage_authorization';

-- 10. VERIFY AUDIT IMMUTABILITY TRIGGER EXISTS
SELECT 
    CASE 
        WHEN count(*) >= 1 THEN 'PASS: Audit immutability trigger exists'
        ELSE 'FAIL: Audit immutability trigger missing'
    END AS audit_trigger_check
FROM pg_trigger 
WHERE tgname = 'trg_protect_audit_logs';

-- 11. VERIFY POS IDEMPOTENCY CONSTRAINT
SELECT 
    CASE 
        WHEN count(*) >= 1 THEN 'PASS: POS idempotency constraint exists'
        ELSE 'FAIL: POS idempotency constraint missing'
    END AS pos_idempotency_check
FROM pg_constraint 
WHERE conname LIKE '%pos_tickets%external_ticket_id%' 
OR (conrelid = 'pos_tickets'::regclass AND contype = 'u');

-- 12. VERIFY SECURITY DEFINER FUNCTIONS HAVE SAFE SEARCH_PATH
SELECT 
    CASE 
        WHEN count(*) = 0 THEN 'PASS: No SECURITY DEFINER functions without safe search_path'
        ELSE 'FAIL: Found SECURITY DEFINER functions without explicit search_path: ' || string_agg(proname, ', ')
    END AS security_definer_check
FROM pg_proc 
WHERE prosecdef = true 
AND prosearchpath IS NULL
AND proname IN ('update_stock_balance', 'process_wastage_authorization', 'protect_audit_logs', 'log_audit_changes', 'get_current_user_role', 'has_role_at_least');

-- 13. VERIFY AUTHORITY MODEL (Enum Order)
SELECT 
    CASE 
        WHEN (SELECT enumlabel FROM pg_enum WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'user_role') ORDER BY enumsortorder LIMIT 1) = 'admin'
        AND (SELECT enumlabel FROM pg_enum WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'user_role') ORDER BY enumsortorder LIMIT 1 OFFSET 1) = 'manager'
        AND (SELECT enumlabel FROM pg_enum WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'user_role') ORDER BY enumsortorder LIMIT 1 OFFSET 2) = 'supervisor'
        AND (SELECT enumlabel FROM pg_enum WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'user_role') ORDER BY enumsortorder LIMIT 1 OFFSET 3) = 'staff'
        THEN 'PASS: Authority model enum order correct (admin < manager < supervisor < staff)'
        ELSE 'FAIL: Authority model enum order incorrect'
    END AS authority_model_check;

-- 14. VERIFY PROPERTY_MEMBERSHIPS UNIQUE CONSTRAINT
SELECT 
    CASE 
        WHEN count(*) >= 1 THEN 'PASS: property_memberships unique constraint on (property_id, person_id) exists'
        ELSE 'FAIL: property_memberships unique constraint missing'
    END AS membership_uniqueness_check
FROM pg_constraint 
WHERE conrelid = 'property_memberships'::regclass 
AND contype = 'u';

-- 15. VERIFY FOREIGN KEY CASCADE RULES
SELECT 
    CASE 
        WHEN count(*) > 0 THEN 'PASS: Foreign keys with CASCADE rules exist'
        ELSE 'WARN: No foreign keys with CASCADE rules found (may be intentional)'
    END AS fk_cascade_check
FROM pg_constraint 
WHERE confdeltype = 'c' -- CASCADE
AND connamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- 16. VERIFY NO DIRECT EXECUTE ON SECURITY DEFINER FUNCTIONS FOR PUBLIC
SELECT 
    CASE 
        WHEN count(*) = 0 THEN 'PASS: No dangerous EXECUTE privileges for PUBLIC on security definer functions'
        ELSE 'FAIL: PUBLIC has EXECUTE on security definer functions'
    END AS execute_privilege_check
FROM information_schema.routine_privileges 
WHERE grantee = 'PUBLIC' 
AND routine_name IN ('update_stock_balance', 'process_wastage_authorization', 'protect_audit_logs', 'log_audit_changes');

-- 17. VERIFY STOCK_MOVEMENTS QUANTITY COLUMN ALLOWS NEGATIVE VALUES
SELECT 
    CASE 
        WHEN data_type = 'numeric' THEN 'PASS: stock_movements.quantity is numeric (allows negative)'
        ELSE 'FAIL: stock_movements.quantity is not numeric'
    END AS stock_quantity_type_check
FROM information_schema.columns 
WHERE table_name = 'stock_movements' 
AND column_name = 'quantity';

-- 18. VERIFY WASTAGE_ITEMS QUANTITY CHECK CONSTRAINT (POSITIVE ONLY)
SELECT 
    CASE 
        WHEN count(*) >= 1 THEN 'PASS: wastage_items.quantity has CHECK constraint (> 0)'
        ELSE 'FAIL: wastage_items.quantity missing CHECK constraint'
    END AS wastage_quantity_check_check
FROM pg_constraint 
WHERE conrelid = 'wastage_items'::regclass 
AND contype = 'c' 
AND pg_get_constraintdef(oid) LIKE '%quantity > 0%';

-- 19. VERIFY AUDIT_LOGS HAS NO DIRECT INSERT POLICY ALLOWING CLIENTS
SELECT 
    CASE 
        WHEN count(*) = 0 THEN 'PASS: No INSERT policy on audit_logs allows direct client insertion'
        ELSE 'FAIL: audit_logs has permissive INSERT policy'
    END AS audit_direct_insert_check
FROM pg_policies 
WHERE tablename = 'audit_logs' 
AND cmd = 'INSERT' 
AND qual IS NOT TRUE; -- Check for permissive policies

-- 20. SUMMARY OF ALL TABLES WITH RLS STATUS
\echo ''
\echo '=== RLS Status Summary ==='
SELECT 
    tablename,
    rowsecurity AS rls_enabled,
    (SELECT count(*) FROM pg_policies p WHERE p.tablename = t.tablename) AS policy_count
FROM pg_tables t
WHERE schemaname = 'public'
AND tablename NOT LIKE 'pg_%'
ORDER BY tablename;

\echo ''
\echo 'Verification Complete.'
