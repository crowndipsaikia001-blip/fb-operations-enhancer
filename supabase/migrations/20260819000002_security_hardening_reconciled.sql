-- ================================================================
-- LOOP Craft Bar & Kitchen: Operations Enhancer MVP
-- Security hardening migration 0002
-- Reconciled against the canonical Revision 5 schema on main.
--
-- This migration intentionally follows the existing schema names:
--   people.auth_id
--   property_memberships.role
--   property_memberships.status
--   get_current_user_role()
--   has_role_at_least()
--
-- It does NOT alter application data. It replaces unsafe RLS policies
-- and fixes audit attribution.
-- ================================================================

BEGIN;

-- ----------------------------------------------------------------
-- 1. Audit attribution
-- ----------------------------------------------------------------
-- The Revision 5 logger wrote changed_by = NULL for every event.
-- Resolve the authenticated Supabase user to public.people.id instead.
-- Service-role/server-side operations may still have NULL when no user
-- JWT is present, which is intentional.

CREATE OR REPLACE FUNCTION public.log_audit_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    current_person_id UUID;
BEGIN
    SELECT id
      INTO current_person_id
      FROM public.people
     WHERE auth_id = (SELECT auth.uid())
     LIMIT 1;

    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.audit_logs
            (table_name, record_id, action, new_data, changed_by)
        VALUES
            (TG_TABLE_NAME, NEW.id, 'INSERT', to_jsonb(NEW), current_person_id);
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO public.audit_logs
            (table_name, record_id, action, old_data, new_data, changed_by)
        VALUES
            (TG_TABLE_NAME, NEW.id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW), current_person_id);
        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO public.audit_logs
            (table_name, record_id, action, old_data, changed_by)
        VALUES
            (TG_TABLE_NAME, OLD.id, 'DELETE', to_jsonb(OLD), current_person_id);
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.log_audit_changes() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.log_audit_changes() FROM anon;
GRANT EXECUTE ON FUNCTION public.log_audit_changes() TO authenticated;

-- ----------------------------------------------------------------
-- 2. Property-scoped/global authorization helper
-- ----------------------------------------------------------------
-- Property creation and initial people provisioning cannot use a
-- target property's membership because the target row does not yet
-- have a membership. Use an existing active membership of the caller.

CREATE OR REPLACE FUNCTION public.has_any_role_at_least(required_role public.user_role)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
          FROM public.people p
          JOIN public.property_memberships pm
            ON pm.person_id = p.id
         WHERE p.auth_id = (SELECT auth.uid())
           AND pm.status = 'active'
           AND pm.role <= required_role
    );
END;
$$;

REVOKE ALL ON FUNCTION public.has_any_role_at_least(public.user_role) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.has_any_role_at_least(public.user_role) FROM anon;
GRANT EXECUTE ON FUNCTION public.has_any_role_at_least(public.user_role) TO authenticated;

-- ----------------------------------------------------------------
-- 3. Replace unsafe bootstrap/global policies
-- ----------------------------------------------------------------

DROP POLICY IF EXISTS "Managers can insert properties" ON public.properties;
CREATE POLICY "Admins can insert properties"
ON public.properties
FOR INSERT
TO authenticated
WITH CHECK ((SELECT public.has_any_role_at_least('admin'::public.user_role)));

DROP POLICY IF EXISTS "Users can view themselves" ON public.people;
CREATE POLICY "Users can view themselves and their property teams"
ON public.people
FOR SELECT
TO authenticated
USING (
    id = (
        SELECT p.id
          FROM public.people p
         WHERE p.auth_id = (SELECT auth.uid())
         LIMIT 1
    )
    OR EXISTS (
        SELECT 1
          FROM public.property_memberships target_pm
          JOIN public.property_memberships viewer_pm
            ON viewer_pm.property_id = target_pm.property_id
          JOIN public.people viewer
            ON viewer.id = viewer_pm.person_id
         WHERE target_pm.person_id = public.people.id
           AND target_pm.status = 'active'
           AND viewer.auth_id = (SELECT auth.uid())
           AND viewer_pm.status = 'active'
           AND viewer_pm.role <= 'manager'::public.user_role
    )
);

DROP POLICY IF EXISTS "Admins can insert people" ON public.people;
-- People records should be provisioned by trusted server-side code after
-- Supabase Auth users are created. Supabase service/secret keys bypass RLS.
-- No authenticated INSERT policy is intentionally provided here.

DROP POLICY IF EXISTS "Admins can delete people" ON public.people;
CREATE POLICY "Admins can delete people in their properties"
ON public.people
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1
          FROM public.property_memberships target_pm
          JOIN public.property_memberships admin_pm
            ON admin_pm.property_id = target_pm.property_id
          JOIN public.people admin_person
            ON admin_person.id = admin_pm.person_id
         WHERE target_pm.person_id = public.people.id
           AND target_pm.status = 'active'
           AND admin_pm.status = 'active'
           AND admin_pm.role <= 'admin'::public.user_role
           AND admin_person.auth_id = (SELECT auth.uid())
    )
);

-- Roles are a system lookup table. They are seeded by the migration and
-- should not be mutable through the browser client.
DROP POLICY IF EXISTS "Admins can modify roles" ON public.roles;
DROP POLICY IF EXISTS "Admins can update roles" ON public.roles;
DROP POLICY IF EXISTS "Admins can delete roles" ON public.roles;

-- ----------------------------------------------------------------
-- 4. Remove direct stock-level mutation policies
-- ----------------------------------------------------------------
-- stock_levels is maintained by update_stock_balance(), a SECURITY
-- DEFINER trigger. Clients must not directly insert/update balances.

DROP POLICY IF EXISTS "System/Triggers update stock levels" ON public.stock_levels;

-- ----------------------------------------------------------------
-- 5. Restrict direct stock-movement insertion
-- ----------------------------------------------------------------
-- Triggered wastage movements are created by SECURITY DEFINER code.
-- Direct client-created movements require supervisor authority.

DROP POLICY IF EXISTS "System/Triggers record movements" ON public.stock_movements;
CREATE POLICY "Supervisors can record stock movements"
ON public.stock_movements
FOR INSERT
TO authenticated
WITH CHECK (
    (SELECT public.has_role_at_least(property_id, 'supervisor'::public.user_role))
);

-- Stock movements remain immutable after insertion.

-- ----------------------------------------------------------------
-- 6. Remove unrestricted POS ingestion from browser clients
-- ----------------------------------------------------------------
-- POS ingestion is an integration/server responsibility. A service/secret
-- key bypasses RLS and can insert these records. No authenticated INSERT
-- policy is intentionally provided.

DROP POLICY IF EXISTS "System can insert POS tickets" ON public.pos_tickets;
DROP POLICY IF EXISTS "System can insert POS ticket items" ON public.pos_ticket_items;

-- ----------------------------------------------------------------
-- 7. Tighten audit-log visibility
-- ----------------------------------------------------------------
-- A NULL changed_by (for trusted service-side operations) must not turn
-- into a broad/global authorization lookup.

DROP POLICY IF EXISTS "Admins can view audit logs" ON public.audit_logs;
CREATE POLICY "Admins can view audit logs for their properties"
ON public.audit_logs
FOR SELECT
TO authenticated
USING (
    changed_by IS NOT NULL
    AND EXISTS (
        SELECT 1
          FROM public.property_memberships pm
          JOIN public.people p
            ON p.id = pm.person_id
         WHERE pm.person_id = public.audit_logs.changed_by
           AND pm.status = 'active'
           AND p.auth_id = (SELECT auth.uid())
           AND pm.role <= 'admin'::public.user_role
    )
);

-- ----------------------------------------------------------------
-- 8. Explicitly keep RLS enabled on all application tables
-- ----------------------------------------------------------------
DO $$
DECLARE
    t RECORD;
BEGIN
    FOR t IN
        SELECT tablename
          FROM pg_tables
         WHERE schemaname = 'public'
           AND tablename NOT LIKE 'pg_%'
    LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t.tablename);
    END LOOP;
END;
$$;

COMMIT;

-- Verification targets after migration:
--   * audit_logs.changed_by is populated for authenticated user actions
--   * stock_levels has no client INSERT/UPDATE policy
--   * stock_movements INSERT requires supervisor authority
--   * POS INSERT has no authenticated-client policy
--   * roles have no authenticated mutation policies
--   * all public application tables have RLS enabled
