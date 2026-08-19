-- ================================================================
-- LOOP Craft Bar & Kitchen: Operations Enhancer MVP
-- Security hardening migration 0002
-- Reconciled against the canonical Revision 5 schema.
-- ================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.log_audit_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    current_person_id UUID;
BEGIN
    SELECT id INTO current_person_id
    FROM public.people
    WHERE auth_id = (SELECT auth.uid())
    LIMIT 1;

    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.audit_logs(table_name, record_id, action, new_data, changed_by)
        VALUES(TG_TABLE_NAME, NEW.id, 'INSERT', to_jsonb(NEW), current_person_id);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO public.audit_logs(table_name, record_id, action, old_data, new_data, changed_by)
        VALUES(TG_TABLE_NAME, NEW.id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW), current_person_id);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO public.audit_logs(table_name, record_id, action, old_data, changed_by)
        VALUES(TG_TABLE_NAME, OLD.id, 'DELETE', to_jsonb(OLD), current_person_id);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.log_audit_changes() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.log_audit_changes() FROM anon;
GRANT EXECUTE ON FUNCTION public.log_audit_changes() TO authenticated;

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
        JOIN public.property_memberships pm ON pm.person_id = p.id
        WHERE p.auth_id = (SELECT auth.uid())
          AND pm.status = 'active'
          AND pm.role <= required_role
    );
END;
$$;

REVOKE ALL ON FUNCTION public.has_any_role_at_least(public.user_role) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.has_any_role_at_least(public.user_role) FROM anon;
GRANT EXECUTE ON FUNCTION public.has_any_role_at_least(public.user_role) TO authenticated;

DROP POLICY IF EXISTS "Managers can insert properties" ON public.properties;
CREATE POLICY "Admins can insert properties"
ON public.properties FOR INSERT TO authenticated
WITH CHECK ((SELECT public.has_any_role_at_least('admin'::public.user_role)));

DROP POLICY IF EXISTS "Users can view themselves" ON public.people;
CREATE POLICY "Users can view themselves and their property teams"
ON public.people FOR SELECT TO authenticated
USING (
    id = (SELECT p.id FROM public.people p WHERE p.auth_id = (SELECT auth.uid()) LIMIT 1)
    OR EXISTS (
        SELECT 1
        FROM public.property_memberships target_pm
        JOIN public.property_memberships viewer_pm ON viewer_pm.property_id = target_pm.property_id
        JOIN public.people viewer ON viewer.id = viewer_pm.person_id
        WHERE target_pm.person_id = public.people.id
          AND target_pm.status = 'active'
          AND viewer.auth_id = (SELECT auth.uid())
          AND viewer_pm.status = 'active'
          AND viewer_pm.role <= 'manager'::public.user_role
    )
);

DROP POLICY IF EXISTS "Admins can insert people" ON public.people;
DROP POLICY IF EXISTS "Admins can delete people" ON public.people;
CREATE POLICY "Admins can delete people in their properties"
ON public.people FOR DELETE TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.property_memberships target_pm
        JOIN public.property_memberships admin_pm ON admin_pm.property_id = target_pm.property_id
        JOIN public.people admin_person ON admin_person.id = admin_pm.person_id
        WHERE target_pm.person_id = public.people.id
          AND target_pm.status = 'active'
          AND admin_pm.status = 'active'
          AND admin_pm.role <= 'admin'::public.user_role
          AND admin_person.auth_id = (SELECT auth.uid())
    )
);

DROP POLICY IF EXISTS "Admins can modify roles" ON public.roles;
DROP POLICY IF EXISTS "Admins can update roles" ON public.roles;
DROP POLICY IF EXISTS "Admins can delete roles" ON public.roles;

DROP POLICY IF EXISTS "System/Triggers update stock levels" ON public.stock_levels;
DROP POLICY IF EXISTS "System Triggers block direct stock inserts" ON public.stock_levels;
DROP POLICY IF EXISTS "System Triggers block direct stock updates" ON public.stock_levels;

CREATE POLICY "System Triggers block direct stock inserts"
ON public.stock_levels FOR INSERT TO authenticated
WITH CHECK (false);

CREATE POLICY "System Triggers block direct stock updates"
ON public.stock_levels FOR UPDATE TO authenticated
USING (false);

DROP POLICY IF EXISTS "System/Triggers record movements" ON public.stock_movements;
CREATE POLICY "Supervisors can record stock movements"
ON public.stock_movements FOR INSERT TO authenticated
WITH CHECK ((SELECT public.has_role_at_least(property_id, 'supervisor'::public.user_role)));

DROP POLICY IF EXISTS "System can insert POS tickets" ON public.pos_tickets;
DROP POLICY IF EXISTS "System can insert POS ticket items" ON public.pos_ticket_items;

DROP POLICY IF EXISTS "Admins can view audit logs" ON public.audit_logs;
CREATE POLICY "Admins can view audit logs for their properties"
ON public.audit_logs FOR SELECT TO authenticated
USING (
    changed_by IS NOT NULL
    AND EXISTS (
        SELECT 1
        FROM public.property_memberships pm
        JOIN public.people p ON p.id = pm.person_id
        WHERE pm.person_id = public.audit_logs.changed_by
          AND pm.status = 'active'
          AND p.auth_id = (SELECT auth.uid())
          AND pm.role <= 'admin'::public.user_role
    )
);

DO $$
DECLARE t RECORD;
BEGIN
    FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename NOT LIKE 'pg_%' LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t.tablename);
    END LOOP;
END;
$$;

COMMIT;
