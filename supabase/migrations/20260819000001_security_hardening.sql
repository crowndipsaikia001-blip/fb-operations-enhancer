-- ============================================================================
-- LOOP Craft Bar & Kitchen: Operations Enhancer MVP
-- Security hardening after Revision 5 review
-- IMPORTANT: This migration does NOT reset or drop application data.
-- ============================================================================

-- 1. Audit actor attribution
-- Resolve the authenticated Supabase user to the application person record.
CREATE OR REPLACE FUNCTION log_audit_changes() RETURNS TRIGGER AS $$
DECLARE
    actor_id UUID;
BEGIN
    SELECT id INTO actor_id
    FROM people
    WHERE auth_id = auth.uid();

    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_logs (table_name, record_id, action, new_data, changed_by)
        VALUES (TG_TABLE_NAME, NEW.id, 'INSERT', to_jsonb(NEW), actor_id);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_logs (table_name, record_id, action, old_data, new_data, changed_by)
        VALUES (TG_TABLE_NAME, NEW.id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW), actor_id);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_logs (table_name, record_id, action, old_data, changed_by)
        VALUES (TG_TABLE_NAME, OLD.id, 'DELETE', to_jsonb(OLD), actor_id);
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 2. Remove ambiguous global role-management policies.
-- Roles are seeded system definitions and should not be modified by client users.
DROP POLICY IF EXISTS "Admins can modify roles" ON roles;
DROP POLICY IF EXISTS "Admins can update roles" ON roles;
DROP POLICY IF EXISTS "Admins can delete roles" ON roles;

-- 3. Property provisioning is a trusted/server-side operation.
-- A client cannot manufacture a new property and then self-authorize against it.
DROP POLICY IF EXISTS "Managers can insert properties" ON properties;

-- 4. Replace People policies with explicit property membership checks.
DROP POLICY IF EXISTS "Users can view themselves" ON people;
DROP POLICY IF EXISTS "Admins can insert people" ON people;
DROP POLICY IF EXISTS "Users can update themselves" ON people;
DROP POLICY IF EXISTS "Admins can delete people" ON people;

CREATE POLICY "Users can view themselves or property team" ON people
    FOR SELECT USING (
        id = (SELECT p.id FROM people p WHERE p.auth_id = auth.uid())
        OR EXISTS (
            SELECT 1
            FROM property_memberships pm
            WHERE pm.person_id = people.id
              AND pm.status = 'active'
              AND has_role_at_least(pm.property_id, 'manager')
        )
    );

CREATE POLICY "Managers can create people" ON people
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1
            FROM property_memberships pm
            WHERE pm.status = 'active'
              AND pm.person_id = (SELECT p.id FROM people p WHERE p.auth_id = auth.uid())
              AND pm.role IN ('admin', 'manager')
        )
    );

CREATE POLICY "Users can update themselves or managers can update team" ON people
    FOR UPDATE USING (
        id = (SELECT p.id FROM people p WHERE p.auth_id = auth.uid())
        OR EXISTS (
            SELECT 1
            FROM property_memberships pm
            WHERE pm.person_id = people.id
              AND pm.status = 'active'
              AND has_role_at_least(pm.property_id, 'manager')
        )
    );

CREATE POLICY "Admins can delete property team members" ON people
    FOR DELETE USING (
        EXISTS (
            SELECT 1
            FROM property_memberships pm
            WHERE pm.person_id = people.id
              AND pm.status = 'active'
              AND has_role_at_least(pm.property_id, 'admin')
        )
    );

-- 5. Restrict direct stock movement creation.
-- Trusted SECURITY DEFINER triggers can still write movements; normal clients need
-- supervisor-level authority for manual adjustments.
DROP POLICY IF EXISTS "System/Triggers record movements" ON stock_movements;
CREATE POLICY "Supervisors can record stock movements" ON stock_movements
    FOR INSERT WITH CHECK (has_role_at_least(property_id, 'supervisor'));

-- 6. POS ingestion belongs to the trusted server/webhook path.
-- Supabase service-role operations bypass RLS; authenticated clients do not need
-- unrestricted INSERT policies here.
DROP POLICY IF EXISTS "System can insert POS tickets" ON pos_tickets;
DROP POLICY IF EXISTS "System can insert POS ticket items" ON pos_ticket_items;

-- 7. Audit logs should only be visible to an administrator of a property that
-- the audited person belongs to. Rows without an actor remain service/system rows
-- and are not exposed to ordinary authenticated clients.
DROP POLICY IF EXISTS "Admins can view audit logs" ON audit_logs;
CREATE POLICY "Admins can view audit logs for their properties" ON audit_logs
    FOR SELECT USING (
        changed_by IS NOT NULL
        AND EXISTS (
            SELECT 1
            FROM property_memberships pm
            WHERE pm.person_id = audit_logs.changed_by
              AND pm.status = 'active'
              AND has_role_at_least(pm.property_id, 'admin')
        )
    );

-- 8. Explicitly document the trusted ingestion model.
COMMENT ON TABLE pos_tickets IS
    'POS tickets are ingested through trusted server-side/service-role paths. Authenticated client INSERT is intentionally blocked by RLS.';
COMMENT ON TABLE stock_movements IS
    'Stock movements are immutable. Manual client inserts require supervisor authority; trusted SECURITY DEFINER workflows may insert system movements.';
COMMENT ON TABLE audit_logs IS
    'Immutable audit trail. Authenticated application actions record changed_by from auth.uid(); trusted service operations may have a NULL actor.';
