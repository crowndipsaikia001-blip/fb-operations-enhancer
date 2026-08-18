-- ================================================================
-- CLEANUP SCRIPT: Start Fresh for Revision 5 Migration
-- Description: Drops conflicting tables to allow clean migration
-- WARNING: This will DELETE ALL DATA in affected tables
-- ================================================================

-- Disable RLS temporarily to allow drops
ALTER TABLE IF EXISTS reservations DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS sections DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS sops DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS tasks DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS people DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS properties DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS roles DISABLE ROW LEVEL SECURITY;

-- Drop dependent objects first (foreign keys, triggers)
DROP TRIGGER IF EXISTS audit_people ON public.people;
DROP TRIGGER IF EXISTS audit_properties ON public.properties;
DROP TRIGGER IF EXISTS audit_reservations ON public.reservations;
DROP TRIGGER IF EXISTS audit_sections ON public.sections;
DROP TRIGGER IF EXISTS audit_sops ON public.sops;
DROP TRIGGER IF EXISTS audit_tasks ON public.tasks;
DROP TRIGGER IF EXISTS audit_roles ON public.roles;

-- Drop functions that may block table drops
DROP FUNCTION IF EXISTS public.rls_auto_enable() CASCADE;
DROP FUNCTION IF EXISTS public.append_audit_log() CASCADE;

-- Drop tables in dependency order
DROP TABLE IF EXISTS public.tasks CASCADE;
DROP TABLE IF EXISTS public.sops CASCADE;
DROP TABLE IF EXISTS public.sections CASCADE;
DROP TABLE IF EXISTS public.reservations CASCADE;
DROP TABLE IF EXISTS public.people CASCADE;
DROP TABLE IF EXISTS public.properties CASCADE;
DROP TABLE IF EXISTS public.roles CASCADE;

-- Drop enums if they conflict with new schema
DROP TYPE IF EXISTS user_role CASCADE;
DROP TYPE IF EXISTS membership_status CASCADE;
DROP TYPE IF EXISTS stock_movement_type CASCADE;
DROP TYPE IF EXISTS transfer_status CASCADE;
DROP TYPE IF EXISTS wastage_status CASCADE;
DROP TYPE IF EXISTS audit_action CASCADE;

-- Clean complete. Ready for fresh migration.
SELECT 'Cleanup complete. All conflicting objects removed.' AS status;
