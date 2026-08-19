-- ================================================================
-- LOOP Craft Bar & Kitchen: Operations Enhancer MVP (Revision 5)
-- Migration: 20260817000001_fb_operations_enhancer_mvp
-- Description: Core schema, RLS, Triggers, and Security for MVP
-- ================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

DO $$ BEGIN CREATE TYPE user_role AS ENUM ('admin', 'manager', 'supervisor', 'staff'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE membership_status AS ENUM ('active', 'inactive', 'suspended'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE stock_movement_type AS ENUM ('purchase', 'adjustment', 'transfer_out', 'transfer_in', 'wastage', 'pos_sale'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE transfer_status AS ENUM ('pending', 'in_transit', 'received', 'cancelled'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE wastage_status AS ENUM ('pending', 'authorized', 'rejected'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE audit_action AS ENUM ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE'); EXCEPTION WHEN duplicate_object THEN null; END $$;

CREATE TABLE IF NOT EXISTS properties (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), name TEXT NOT NULL, address TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), name user_role UNIQUE NOT NULL, description TEXT
);
INSERT INTO roles (name, description) VALUES
 ('admin','Full system access'),('manager','Property management access'),('supervisor','Operational oversight'),('staff','Standard operational access')
ON CONFLICT (name) DO NOTHING;
CREATE TABLE IF NOT EXISTS people (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), auth_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL, email TEXT NOT NULL, created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS property_memberships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    person_id UUID NOT NULL REFERENCES people(id) ON DELETE CASCADE, role user_role NOT NULL,
    status membership_status DEFAULT 'active', joined_at TIMESTAMPTZ DEFAULT NOW(), UNIQUE(property_id, person_id)
);
CREATE INDEX IF NOT EXISTS idx_property_memberships_person ON property_memberships(person_id);
CREATE INDEX IF NOT EXISTS idx_property_memberships_property ON property_memberships(property_id);

CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    name TEXT NOT NULL, parent_id UUID REFERENCES categories(id), created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id), name TEXT NOT NULL, sku TEXT, unit_of_measure TEXT DEFAULT 'unit',
    cost_price NUMERIC(12,2), sale_price NUMERIC(12,2), is_active BOOLEAN DEFAULT true, created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS stock_levels (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE, quantity NUMERIC(12,4) DEFAULT 0,
    last_counted_at TIMESTAMPTZ, updated_at TIMESTAMPTZ DEFAULT NOW(), UNIQUE(item_id, property_id)
);
CREATE TABLE IF NOT EXISTS stock_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), item_id UUID NOT NULL REFERENCES items(id),
    property_id UUID NOT NULL REFERENCES properties(id), quantity NUMERIC(12,4) NOT NULL,
    movement_type stock_movement_type NOT NULL, reference_id UUID, reason TEXT,
    performed_by UUID REFERENCES people(id), created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS transfer_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), source_property_id UUID NOT NULL REFERENCES properties(id),
    destination_property_id UUID NOT NULL REFERENCES properties(id), status transfer_status DEFAULT 'pending',
    requested_by UUID REFERENCES people(id), approved_by UUID REFERENCES people(id), requested_at TIMESTAMPTZ DEFAULT NOW(), approved_at TIMESTAMPTZ
);
CREATE TABLE IF NOT EXISTS transfer_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), transfer_id UUID NOT NULL REFERENCES transfer_requests(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id), quantity NUMERIC(12,4) NOT NULL CHECK (quantity > 0)
);
CREATE TABLE IF NOT EXISTS purchase_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), property_id UUID NOT NULL REFERENCES properties(id), supplier_name TEXT,
    order_date DATE DEFAULT CURRENT_DATE, status TEXT DEFAULT 'pending', total_cost NUMERIC(12,2),
    created_by UUID REFERENCES people(id), created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS purchase_order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), order_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id), quantity NUMERIC(12,4) NOT NULL CHECK (quantity > 0), unit_cost NUMERIC(12,2), total_cost NUMERIC(12,2)
);
CREATE TABLE IF NOT EXISTS wastage_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), property_id UUID NOT NULL REFERENCES properties(id), status wastage_status DEFAULT 'pending',
    reason TEXT, reported_by UUID REFERENCES people(id), authorized_by UUID REFERENCES people(id), reported_at TIMESTAMPTZ DEFAULT NOW(), authorized_at TIMESTAMPTZ
);
CREATE TABLE IF NOT EXISTS wastage_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), wastage_id UUID NOT NULL REFERENCES wastage_requests(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id), quantity NUMERIC(12,4) NOT NULL CHECK (quantity > 0), reason_detail TEXT
);
CREATE TABLE IF NOT EXISTS pos_tickets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), property_id UUID NOT NULL REFERENCES properties(id),
    external_ticket_id TEXT NOT NULL, source_system TEXT NOT NULL, total_amount NUMERIC(12,2),
    ticket_date TIMESTAMPTZ DEFAULT NOW(), processed_at TIMESTAMPTZ DEFAULT NOW(), UNIQUE(property_id, source_system, external_ticket_id)
);
CREATE TABLE IF NOT EXISTS pos_ticket_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), ticket_id UUID NOT NULL REFERENCES pos_tickets(id) ON DELETE CASCADE,
    item_id UUID REFERENCES items(id), external_item_id TEXT, item_name TEXT, quantity NUMERIC(12,4) NOT NULL, unit_price NUMERIC(12,2)
);
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), table_name TEXT NOT NULL, record_id UUID NOT NULL, action audit_action NOT NULL,
    old_data JSONB, new_data JSONB, changed_by UUID REFERENCES people(id), changed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION update_stock_balance() RETURNS TRIGGER AS $$
DECLARE current_balance NUMERIC(12,4);
BEGIN
    SELECT COALESCE(SUM(quantity),0) INTO current_balance FROM stock_movements WHERE item_id=NEW.item_id AND property_id=NEW.property_id;
    UPDATE stock_levels SET quantity=current_balance, updated_at=NOW() WHERE item_id=NEW.item_id AND property_id=NEW.property_id;
    IF NOT FOUND THEN INSERT INTO stock_levels(item_id,property_id,quantity,updated_at) VALUES(NEW.item_id,NEW.property_id,current_balance,NOW()); END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp;
CREATE TRIGGER trg_update_stock_balance AFTER INSERT OR UPDATE OF quantity,item_id,property_id ON stock_movements FOR EACH ROW EXECUTE FUNCTION update_stock_balance();

CREATE OR REPLACE FUNCTION process_wastage_authorization() RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status='rejected' AND NEW.status='authorized' THEN RAISE EXCEPTION 'Cannot authorize a previously rejected wastage request. Create a new request.'; END IF;
    IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status='authorized' THEN
        INSERT INTO stock_movements(item_id,property_id,quantity,movement_type,reference_id,reason,performed_by)
        SELECT wi.item_id,wr.property_id,-wi.quantity,'wastage',wr.id,wi.reason_detail,wr.authorized_by
        FROM wastage_items wi JOIN wastage_requests wr ON wi.wastage_id=wr.id WHERE wr.id=NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp;
CREATE TRIGGER trg_process_wastage_authorization AFTER UPDATE OF status ON wastage_requests FOR EACH ROW EXECUTE FUNCTION process_wastage_authorization();

CREATE OR REPLACE FUNCTION protect_audit_logs() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP='UPDATE' OR TG_OP='DELETE' THEN RAISE EXCEPTION 'Audit logs are immutable. Direct % prohibited.',TG_OP; END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp;
CREATE TRIGGER trg_protect_audit_logs BEFORE UPDATE OR DELETE ON audit_logs FOR EACH ROW EXECUTE FUNCTION protect_audit_logs();

CREATE OR REPLACE FUNCTION log_audit_changes() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP='INSERT' THEN
        INSERT INTO audit_logs(table_name,record_id,action,new_data,changed_by) VALUES(TG_TABLE_NAME,NEW.id,'INSERT',to_jsonb(NEW),NULL); RETURN NEW;
    ELSIF TG_OP='UPDATE' THEN
        INSERT INTO audit_logs(table_name,record_id,action,old_data,new_data,changed_by) VALUES(TG_TABLE_NAME,NEW.id,'UPDATE',to_jsonb(OLD),to_jsonb(NEW),NULL); RETURN NEW;
    ELSIF TG_OP='DELETE' THEN
        INSERT INTO audit_logs(table_name,record_id,action,old_data,changed_by) VALUES(TG_TABLE_NAME,OLD.id,'DELETE',to_jsonb(OLD),NULL); RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp;

DO $$ DECLARE t TEXT; BEGIN
    FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename!='audit_logs' AND tablename NOT LIKE 'pg_%' LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_audit_%I ON %I',t,t);
        EXECUTE format('CREATE TRIGGER trg_audit_%I AFTER INSERT OR UPDATE OR DELETE ON %I FOR EACH ROW EXECUTE FUNCTION log_audit_changes()',t,t);
    END LOOP;
END $$;

DO $$ DECLARE t TEXT; BEGIN
    FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename NOT LIKE 'pg_%' LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY',t);
    END LOOP;
END $$;

CREATE OR REPLACE FUNCTION get_current_user_role(target_property_id UUID) RETURNS user_role AS $$
DECLARE user_role_val user_role; current_person_id UUID;
BEGIN
    SELECT id INTO current_person_id FROM people WHERE auth_id=auth.uid();
    IF current_person_id IS NULL THEN RETURN NULL; END IF;
    SELECT role INTO user_role_val FROM property_memberships WHERE person_id=current_person_id AND property_id=target_property_id AND status='active' ORDER BY role ASC LIMIT 1;
    RETURN user_role_val;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp;
CREATE OR REPLACE FUNCTION has_role_at_least(target_property_id UUID, required_role user_role) RETURNS BOOLEAN AS $$
DECLARE user_role_val user_role;
BEGIN
    user_role_val=get_current_user_role(target_property_id);
    IF user_role_val IS NULL THEN RETURN FALSE; END IF;
    RETURN user_role_val <= required_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp;

CREATE POLICY "Users can view properties they belong to" ON properties FOR SELECT USING (has_role_at_least(id,'staff'));
CREATE POLICY "Managers can insert properties" ON properties FOR INSERT WITH CHECK (has_role_at_least(id,'manager'));
CREATE POLICY "Managers can update properties they belong to" ON properties FOR UPDATE USING (has_role_at_least(id,'manager'));
CREATE POLICY "Admins can delete properties" ON properties FOR DELETE USING (has_role_at_least(id,'admin'));
CREATE POLICY "Users can view themselves" ON people FOR SELECT USING (id=(SELECT id FROM people WHERE auth_id=auth.uid()) OR has_role_at_least((SELECT property_id FROM property_memberships WHERE person_id=people.id LIMIT 1),'manager'));
CREATE POLICY "Admins can insert people" ON people FOR INSERT WITH CHECK (has_role_at_least((SELECT property_id FROM property_memberships WHERE person_id=people.id LIMIT 1),'admin'));
CREATE POLICY "Users can update themselves" ON people FOR UPDATE USING (id=(SELECT id FROM people WHERE auth_id=auth.uid()));
CREATE POLICY "Admins can delete people" ON people FOR DELETE USING (has_role_at_least((SELECT property_id FROM property_memberships WHERE person_id=people.id LIMIT 1),'admin'));
CREATE POLICY "Users can view memberships in their properties" ON property_memberships FOR SELECT USING (has_role_at_least(property_id,'staff'));
CREATE POLICY "Managers can manage memberships" ON property_memberships FOR INSERT WITH CHECK (has_role_at_least(property_id,'manager'));
CREATE POLICY "Managers can update memberships" ON property_memberships FOR UPDATE USING (has_role_at_least(property_id,'manager'));
CREATE POLICY "Admins can delete memberships" ON property_memberships FOR DELETE USING (has_role_at_least(property_id,'admin'));
CREATE POLICY "Everyone can view roles" ON roles FOR SELECT USING (true);
CREATE POLICY "Admins can modify roles" ON roles FOR INSERT WITH CHECK (has_role_at_least((SELECT property_id FROM property_memberships LIMIT 1),'admin'));
CREATE POLICY "Admins can update roles" ON roles FOR UPDATE USING (has_role_at_least((SELECT property_id FROM property_memberships LIMIT 1),'admin'));
CREATE POLICY "Admins can delete roles" ON roles FOR DELETE USING (has_role_at_least((SELECT property_id FROM property_memberships LIMIT 1),'admin'));
CREATE POLICY "Staff can view categories" ON categories FOR SELECT USING (has_role_at_least(property_id,'staff'));
CREATE POLICY "Supervisors can insert categories" ON categories FOR INSERT WITH CHECK (has_role_at_least(property_id,'supervisor'));
CREATE POLICY "Supervisors can update categories" ON categories FOR UPDATE USING (has_role_at_least(property_id,'supervisor'));
CREATE POLICY "Managers can delete categories" ON categories FOR DELETE USING (has_role_at_least(property_id,'manager'));
CREATE POLICY "Staff can view items" ON items FOR SELECT USING (has_role_at_least(property_id,'staff'));
CREATE POLICY "Supervisors can insert items" ON items FOR INSERT WITH CHECK (has_role_at_least(property_id,'supervisor'));
CREATE POLICY "Supervisors can update items" ON items FOR UPDATE USING (has_role_at_least(property_id,'supervisor'));
CREATE POLICY "Managers can delete items" ON items FOR DELETE USING (has_role_at_least(property_id,'manager'));
CREATE POLICY "Staff can view stock levels" ON stock_levels FOR SELECT USING (has_role_at_least(property_id,'staff'));
CREATE POLICY "System Triggers block direct stock inserts" ON stock_levels FOR INSERT WITH CHECK (false);
CREATE POLICY "System Triggers block direct stock updates" ON stock_levels FOR UPDATE USING (false);
CREATE POLICY "Managers can reset stock levels" ON stock_levels FOR DELETE USING (has_role_at_least(property_id,'manager'));
CREATE POLICY "Staff can view stock movements" ON stock_movements FOR SELECT USING (has_role_at_least(property_id,'staff'));
CREATE POLICY "System/Triggers record movements" ON stock_movements FOR INSERT WITH CHECK (true);
CREATE POLICY "Prevent modification of movements" ON stock_movements FOR UPDATE USING (false);
CREATE POLICY "Prevent deletion of movements" ON stock_movements FOR DELETE USING (false);
CREATE POLICY "Staff can view transfers for their properties" ON transfer_requests FOR SELECT USING (has_role_at_least(source_property_id,'staff') OR has_role_at_least(destination_property_id,'staff'));
CREATE POLICY "Supervisors can request transfers" ON transfer_requests FOR INSERT WITH CHECK (has_role_at_least(source_property_id,'supervisor'));
CREATE POLICY "Managers can approve transfers" ON transfer_requests FOR UPDATE USING ((has_role_at_least(source_property_id,'manager') OR has_role_at_least(destination_property_id,'manager')) AND status IN ('pending','in_transit'));
CREATE POLICY "Managers can cancel transfers" ON transfer_requests FOR DELETE USING (has_role_at_least(source_property_id,'manager') AND status='pending');
CREATE POLICY "Staff can view transfer items" ON transfer_items FOR SELECT USING (EXISTS(SELECT 1 FROM transfer_requests tr WHERE tr.id=transfer_items.transfer_id AND (has_role_at_least(tr.source_property_id,'staff') OR has_role_at_least(tr.destination_property_id,'staff'))));
CREATE POLICY "Supervisors can add transfer items" ON transfer_items FOR INSERT WITH CHECK (EXISTS(SELECT 1 FROM transfer_requests tr WHERE tr.id=transfer_items.transfer_id AND has_role_at_least(tr.source_property_id,'supervisor')));
CREATE POLICY "Prevent modification of transfer items" ON transfer_items FOR UPDATE USING (false);
CREATE POLICY "Supervisors can remove transfer items" ON transfer_items FOR DELETE USING (EXISTS(SELECT 1 FROM transfer_requests tr WHERE tr.id=transfer_items.transfer_id AND has_role_at_least(tr.source_property_id,'supervisor') AND tr.status='pending'));
CREATE POLICY "Staff can view purchase orders" ON purchase_orders FOR SELECT USING (has_role_at_least(property_id,'staff'));
CREATE POLICY "Supervisors can create purchase orders" ON purchase_orders FOR INSERT WITH CHECK (has_role_at_least(property_id,'supervisor'));
CREATE POLICY "Supervisors can update purchase orders" ON purchase_orders FOR UPDATE USING (has_role_at_least(property_id,'supervisor') AND status='pending');
CREATE POLICY "Managers can delete purchase orders" ON purchase_orders FOR DELETE USING (has_role_at_least(property_id,'manager') AND status='pending');
CREATE POLICY "Staff can view PO items" ON purchase_order_items FOR SELECT USING (EXISTS(SELECT 1 FROM purchase_orders po WHERE po.id=purchase_order_items.order_id AND has_role_at_least(po.property_id,'staff')));
CREATE POLICY "Supervisors can add PO items" ON purchase_order_items FOR INSERT WITH CHECK (EXISTS(SELECT 1 FROM purchase_orders po WHERE po.id=purchase_order_items.order_id AND has_role_at_least(po.property_id,'supervisor')));
CREATE POLICY "Prevent modification of PO items" ON purchase_order_items FOR UPDATE USING (false);
CREATE POLICY "Supervisors can remove PO items" ON purchase_order_items FOR DELETE USING (EXISTS(SELECT 1 FROM purchase_orders po WHERE po.id=purchase_order_items.order_id AND has_role_at_least(po.property_id,'supervisor') AND po.status='pending'));
CREATE POLICY "Staff can view wastage requests" ON wastage_requests FOR SELECT USING (has_role_at_least(property_id,'staff'));
CREATE POLICY "Staff can report wastage" ON wastage_requests FOR INSERT WITH CHECK (has_role_at_least(property_id,'staff'));
CREATE POLICY "Managers can authorize/reject wastage" ON wastage_requests FOR UPDATE USING (has_role_at_least(property_id,'manager') AND status='pending');
CREATE POLICY "Managers can delete wastage requests" ON wastage_requests FOR DELETE USING (has_role_at_least(property_id,'manager') AND status='pending');
CREATE POLICY "Staff can view wastage items" ON wastage_items FOR SELECT USING (EXISTS(SELECT 1 FROM wastage_requests wr WHERE wr.id=wastage_items.wastage_id AND has_role_at_least(wr.property_id,'staff')));
CREATE POLICY "Staff can add wastage items" ON wastage_items FOR INSERT WITH CHECK (EXISTS(SELECT 1 FROM wastage_requests wr WHERE wr.id=wastage_items.wastage_id AND has_role_at_least(wr.property_id,'staff')));
CREATE POLICY "Prevent modification of wastage items" ON wastage_items FOR UPDATE USING (false);
CREATE POLICY "Staff can remove wastage items" ON wastage_items FOR DELETE USING (EXISTS(SELECT 1 FROM wastage_requests wr WHERE wr.id=wastage_items.wastage_id AND has_role_at_least(wr.property_id,'staff') AND wr.status='pending'));
CREATE POLICY "Staff can view POS tickets" ON pos_tickets FOR SELECT USING (has_role_at_least(property_id,'staff'));
CREATE POLICY "System can insert POS tickets" ON pos_tickets FOR INSERT WITH CHECK (true);
CREATE POLICY "Prevent modification of POS tickets" ON pos_tickets FOR UPDATE USING (false);
CREATE POLICY "Prevent deletion of POS tickets" ON pos_tickets FOR DELETE USING (false);
CREATE POLICY "Staff can view POS ticket items" ON pos_ticket_items FOR SELECT USING (EXISTS(SELECT 1 FROM pos_tickets pt WHERE pt.id=pos_ticket_items.ticket_id AND has_role_at_least(pt.property_id,'staff')));
CREATE POLICY "System can insert POS ticket items" ON pos_ticket_items FOR INSERT WITH CHECK (true);
CREATE POLICY "Prevent modification of POS ticket items" ON pos_ticket_items FOR UPDATE USING (false);
CREATE POLICY "Prevent deletion of POS ticket items" ON pos_ticket_items FOR DELETE USING (false);
CREATE POLICY "Admins can view audit logs" ON audit_logs FOR SELECT USING (has_role_at_least((SELECT property_id FROM property_memberships WHERE person_id=changed_by LIMIT 1),'admin'));
CREATE POLICY "No direct inserts to audit logs" ON audit_logs FOR INSERT WITH CHECK (false);
CREATE POLICY "No updates to audit logs" ON audit_logs FOR UPDATE USING (false);
CREATE POLICY "No deletes to audit logs" ON audit_logs FOR DELETE USING (false);

REVOKE ALL ON FUNCTION update_stock_balance() FROM PUBLIC;
REVOKE ALL ON FUNCTION process_wastage_authorization() FROM PUBLIC;
REVOKE ALL ON FUNCTION protect_audit_logs() FROM PUBLIC;
REVOKE ALL ON FUNCTION log_audit_changes() FROM PUBLIC;
REVOKE ALL ON FUNCTION get_current_user_role(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION has_role_at_least(UUID,user_role) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_current_user_role(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION has_role_at_least(UUID,user_role) TO authenticated;
