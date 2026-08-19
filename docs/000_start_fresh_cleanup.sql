-- ================================================================
-- HISTORICAL CLEANUP SCRIPT: Start Fresh for Revision 5 Migration
-- WARNING: Destructive. Deletes data in affected tables.
-- This file is intentionally kept OUTSIDE supabase/migrations so
-- Supabase CLI cannot treat it as an executable migration.
-- ================================================================

ALTER TABLE IF EXISTS reservations DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS sections DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS sops DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS tasks DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS people DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS properties DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS roles DISABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS audit_people ON public.people;
DROP TRIGGER IF EXISTS audit_properties ON public.properties;
DROP TRIGGER IF EXISTS audit_reservations ON public.reservations;
DROP TRIGGER IF EXISTS audit_sections ON public.sections;
DROP TRIGGER IF EXISTS audit_sops ON public.sops;
DROP TRIGGER IF EXISTS audit_tasks ON public.tasks;
DROP TRIGGER IF EXISTS audit_roles ON public.roles;

DROP FUNCTION IF EXISTS public.rls_auto_enable() CASCADE;
DROP FUNCTION IF EXISTS public.append_audit_log() CASCADE;

DROP TABLE IF EXISTS public.tasks CASCADE;
DROP TABLE IF EXISTS public.sops CASCADE;
DROP TABLE IF EXISTS public.sections CASCADE;
DROP TABLE IF EXISTS public.reservations CASCADE;
DROP TABLE IF EXISTS public.people CASCADE;
DROP TABLE IF EXISTS public.properties CASCADE;
DROP TABLE IF EXISTS public.roles CASCADE;

DROP TYPE IF EXISTS user_role CASCADE;
DROP TYPE IF EXISTS membership_status CASCADE;
DROP TYPE IF EXISTS stock_movement_type CASCADE;
DROP TYPE IF EXISTS transfer_status CASCADE;
DROP TYPE IF EXISTS wastage_status CASCADE;
DROP TYPE IF EXISTS audit_action CASCADE;

SELECT 'Historical cleanup complete. This script must be reviewed before manual execution.' AS status;
